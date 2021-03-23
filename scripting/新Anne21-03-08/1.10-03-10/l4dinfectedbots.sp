#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#define TEAM_SPECTATOR		1
#define TEAM_SURVIVORS 		2
#define TEAM_INFECTED 		3
#define ZOMBIECLASS_SMOKER	1
#define ZOMBIECLASS_BOOMER	2
#define ZOMBIECLASS_HUNTER	3
#define ZOMBIECLASS_SPITTER	4
#define ZOMBIECLASS_JOCKEY	5
#define ZOMBIECLASS_CHARGER	6
#define TRACE_TOLERANCE 150.0
static const String:CLASSNAME_INFECTED[]			= "infected";
static const String:CLASSNAME_WITCH[]				= "witch";
static const String:CLASSNAME_PHYSPROPS[]			= "prop_physics";
static InfectedRealCount;
static InfectedBotCount;
static InfectedBotQueue;
static GameMode;
static BoomerLimit;
static SmokerLimit;
static HunterLimit;
static SpitterLimit;
static JockeyLimit;
static ChargerLimit;
static MaxPlayerZombies;
static BotReady;
static ZOMBIECLASS_TANK = 8;
static GetSpawnTime[MAXPLAYERS+1];
static PlayersInServer;
static InfectedSpawnTimeMax
static InfectedSpawnTimeMin
static InitialSpawnInt
static TankLimit
static bool:b_HasRoundStarted;
static bool:b_HasRoundEnded;
static bool:b_LeftSaveRoom;
static bool:canSpawnBoomer;
static bool:canSpawnSmoker;
static bool:canSpawnHunter;
static bool:canSpawnSpitter;
static bool:canSpawnJockey;
static bool:canSpawnCharger;
static bool:DirectorSpawn;
static bool:PlayerLifeState[MAXPLAYERS+1];
static bool:InitialSpawn;
static bool:b_IsL4D2;
static bool:AlreadyGhosted[MAXPLAYERS+1];
static bool:AlreadyGhostedBot[MAXPLAYERS+1];
static bool:PlayerHasEnteredStart[MAXPLAYERS+1];
static bool:AdjustSpawnTimes
static bool:Coordination
static bool:DisableSpawnsTank
static Handle:h_BoomerLimit;
static Handle:h_SmokerLimit;
static Handle:h_HunterLimit;
static Handle:h_SpitterLimit;
static Handle:h_JockeyLimit;
static Handle:h_ChargerLimit;
static Handle:h_MaxPlayerZombies;
static Handle:h_InfectedSpawnTimeMax;
static Handle:h_InfectedSpawnTimeMin;
static Handle:h_DirectorSpawn;
static Handle:h_Coordination;
static Handle:h_idletime_b4slay;
static Handle:h_InitialSpawn;
static Handle:FightOrDieTimer[MAXPLAYERS+1];
static Handle:h_BotGhostTime;
static Handle:h_DisableSpawnsTank;
static Handle:h_TankLimit;
static Handle:h_AdjustSpawnTimes;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) 
{
	decl String:GameName[64];
	GetGameFolderName(GameName, sizeof(GameName));
	if (StrEqual(GameName, "left4dead2", false))
		b_IsL4D2 = true;
	return APLRes_Success; 
}

public OnPluginStart()
{
	h_BoomerLimit = CreateConVar("l4d_infectedbots_boomer_limit", "0");
	h_SmokerLimit = CreateConVar("l4d_infectedbots_smoker_limit", "0");
	h_TankLimit = CreateConVar("l4d_infectedbots_tank_limit", "0");
	h_SpitterLimit = CreateConVar("l4d_infectedbots_spitter_limit", "0");
	h_JockeyLimit = CreateConVar("l4d_infectedbots_jockey_limit", "0");
	h_ChargerLimit = CreateConVar("l4d_infectedbots_charger_limit", "0");
	h_HunterLimit = CreateConVar("l4d_infectedbots_hunter_limit", "0");
	h_MaxPlayerZombies = CreateConVar("l4d_infected_limit", "4"); 
	h_InfectedSpawnTimeMax = CreateConVar("l4d_infectedbots_spawn_time_max", "0");
	h_InfectedSpawnTimeMin = CreateConVar("l4d_infectedbots_spawn_time_min", "0");
	h_DirectorSpawn = CreateConVar("l4d_infectedbots_director_spawn_times", "1");
	h_Coordination = CreateConVar("l4d_infectedbots_coordination", "0");
	h_idletime_b4slay = CreateConVar("l4d_infectedbots_lifespan", "10");
	h_InitialSpawn = CreateConVar("l4d_infectedbots_initial_spawn_timer", "1");
	h_BotGhostTime = CreateConVar("l4d_infectedbots_ghost_time", "0.5");
	h_DisableSpawnsTank = CreateConVar("l4d_infectedbots_spawns_disabled_tank", "0");
	h_AdjustSpawnTimes = CreateConVar("l4d_infectedbots_adjust_spawn_times", "0");
	HookConVarChange(h_BoomerLimit, ConVarBoomerLimit);
	BoomerLimit = GetConVarInt(h_BoomerLimit);
	HookConVarChange(h_SmokerLimit, ConVarSmokerLimit);
	SmokerLimit = GetConVarInt(h_SmokerLimit);
	HookConVarChange(h_HunterLimit, ConVarHunterLimit);
	HunterLimit = GetConVarInt(h_HunterLimit);
	HookConVarChange(h_SpitterLimit, ConVarSpitterLimit);
	SpitterLimit = GetConVarInt(h_SpitterLimit);
	HookConVarChange(h_JockeyLimit, ConVarJockeyLimit);
	JockeyLimit = GetConVarInt(h_JockeyLimit);
	HookConVarChange(h_ChargerLimit, ConVarChargerLimit);
	ChargerLimit = GetConVarInt(h_ChargerLimit);
	HookConVarChange(h_MaxPlayerZombies, ConVarMaxPlayerZombies);
	MaxPlayerZombies = GetConVarInt(h_MaxPlayerZombies);
	HookConVarChange(h_DirectorSpawn, ConVarDirectorSpawn);
	DirectorSpawn = GetConVarBool(h_DirectorSpawn);
	HookConVarChange(h_AdjustSpawnTimes, ConVarAdjustSpawnTimes);
	Coordination = GetConVarBool(h_Coordination);
	HookConVarChange(h_Coordination, ConVarCoordination);
	DisableSpawnsTank = GetConVarBool(h_DisableSpawnsTank);
	HookConVarChange(h_DisableSpawnsTank, ConVarDisableSpawnsTank);
	HookConVarChange(h_InfectedSpawnTimeMax, ConVarInfectedSpawnTimeMax);
	InfectedSpawnTimeMax = GetConVarInt(h_InfectedSpawnTimeMax);
	HookConVarChange(h_InfectedSpawnTimeMin, ConVarInfectedSpawnTimeMin);
	InfectedSpawnTimeMin = GetConVarInt(h_InfectedSpawnTimeMin);
	HookConVarChange(h_InitialSpawn, ConVarInitialSpawn);
	InitialSpawnInt = GetConVarInt(h_InitialSpawn);
	HookConVarChange(h_TankLimit, ConVarTankLimit);
	TankLimit = GetConVarInt(h_TankLimit);
	HookEvent("round_start", evtRoundStart);
	HookEvent("round_end", evtRoundEnd, EventHookMode_Pre);
	HookEvent("player_death", evtPlayerDeath, EventHookMode_Pre);
	HookEvent("player_team", evtPlayerTeam);
	//HookEvent("player_spawn", evtPlayerSpawn);
	HookEvent("finale_start", evtFinaleStart);
	HookEvent("player_first_spawn", evtPlayerFirstSpawned);
	HookEvent("player_entered_start_area", evtPlayerFirstSpawned);
	HookEvent("player_entered_checkpoint", evtPlayerFirstSpawned);
	HookEvent("player_transitioned", evtPlayerFirstSpawned);
	HookEvent("player_left_start_area", evtPlayerFirstSpawned);
	HookEvent("player_left_checkpoint", evtPlayerFirstSpawned);
}

public ConVarBoomerLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	BoomerLimit = GetConVarInt(h_BoomerLimit);
}

public ConVarSmokerLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SmokerLimit = GetConVarInt(h_SmokerLimit);
}

public ConVarHunterLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	HunterLimit = GetConVarInt(h_HunterLimit);
}

public ConVarSpitterLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SpitterLimit = GetConVarInt(h_SpitterLimit);
}

public ConVarJockeyLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	JockeyLimit = GetConVarInt(h_JockeyLimit);
}

public ConVarChargerLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	ChargerLimit = GetConVarInt(h_ChargerLimit);
}

public ConVarInfectedSpawnTimeMax(Handle:convar, const String:oldValue[], const String:newValue[])
{
	InfectedSpawnTimeMax = GetConVarInt(h_InfectedSpawnTimeMax);
}

public ConVarInfectedSpawnTimeMin(Handle:convar, const String:oldValue[], const String:newValue[])
{
	InfectedSpawnTimeMin = GetConVarInt(h_InfectedSpawnTimeMin);
}

public ConVarInitialSpawn(Handle:convar, const String:oldValue[], const String:newValue[])
{
	InitialSpawnInt = GetConVarInt(h_InitialSpawn);
}

public ConVarTankLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	TankLimit = GetConVarInt(h_TankLimit);
}

public ConVarAdjustSpawnTimes(Handle:convar, const String:oldValue[], const String:newValue[])
{
	AdjustSpawnTimes = GetConVarBool(h_AdjustSpawnTimes);
}

public ConVarCoordination(Handle:convar, const String:oldValue[], const String:newValue[])
{
	Coordination = GetConVarBool(h_Coordination);
}

public ConVarDisableSpawnsTank(Handle:convar, const String:oldValue[], const String:newValue[])
{
	DisableSpawnsTank = GetConVarBool(h_DisableSpawnsTank);
}

public ConVarMaxPlayerZombies(Handle:convar, const String:oldValue[], const String:newValue[])
{
	MaxPlayerZombies = GetConVarInt(h_MaxPlayerZombies);
	CreateTimer(0.1, MaxSpecialsSet);
}

public ConVarDirectorSpawn(Handle:convar, const String:oldValue[], const String:newValue[])
{
	DirectorSpawn = GetConVarBool(h_DirectorSpawn);
	if (!DirectorSpawn)
	{
		TweakSettings();
		CheckIfBotsNeeded(true, false);
	}
	else
	{
		DirectorStuff();
	}
}

TweakSettings()
{
	SetConVarInt(FindConVar("z_jockey_leap_time"), 0);
	SetConVarInt(FindConVar("z_spitter_max_wait_time"), 0);
	SetConVarFloat(FindConVar("smoker_tongue_delay"), 0.0);
	SetConVarFloat(FindConVar("boomer_vomit_delay"), 0.0);
	SetConVarFloat(FindConVar("boomer_exposed_time_tolerance"), 0.0);
	SetConVarInt(FindConVar("hunter_leap_away_give_up_range"), 0);
	SetConVarInt(FindConVar("z_hunter_lunge_distance"), 5000);
	SetConVarInt(FindConVar("hunter_pounce_ready_range"), 1500);
	SetConVarFloat(FindConVar("hunter_pounce_loft_rate"), 0.055);
	SetConVarFloat(FindConVar("z_hunter_lunge_stagger_time"), 0.0);
	SetConVarInt(FindConVar("z_attack_flow_range"), 50000);
	SetConVarInt(FindConVar("director_spectate_specials"), 1);
	SetConVarInt(FindConVar("z_spawn_safety_range"), 100);
	SetConVarInt(FindConVar("z_spawn_flow_limit"), 50000);
}

public Action:evtRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (b_HasRoundStarted)
		return;
	b_LeftSaveRoom = false;
	b_HasRoundEnded = false;
	b_HasRoundStarted = true;
	new flags = GetConVarFlags(FindConVar("z_max_player_zombies"));
	SetConVarBounds(FindConVar("z_max_player_zombies"), ConVarBound_Upper, false);
	SetConVarFlags(FindConVar("z_max_player_zombies"), flags & ~FCVAR_NOTIFY);
	CreateTimer(0.4, MaxSpecialsSet);
	InfectedBotQueue = 0;
	BotReady = 0;
	InitialSpawn = false;
	if (!DirectorSpawn)
		TweakSettings();
	else
	DirectorStuff();
	CreateTimer(1.0, PlayerLeftStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:evtPlayerFirstSpawned(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (b_HasRoundEnded)
		return;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client)
		return;
	if (IsFakeClient(client))
		return;
	if (PlayerHasEnteredStart[client])
		return;
	AlreadyGhosted[client] = false;
	PlayerHasEnteredStart[client] = true;
}

public Action:MaxSpecialsSet(Handle:Timer)
{
	SetConVarInt(FindConVar("z_max_player_zombies"), MaxPlayerZombies);
}

DirectorStuff()
{	
	SetConVarInt(FindConVar("z_spawn_safety_range"), 100);
	SetConVarInt(FindConVar("director_spectate_specials"), 1);
}
public Action:evtRoundEnd (Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!b_HasRoundEnded)
	{
		b_HasRoundEnded = true;
		b_HasRoundStarted = false;
		b_LeftSaveRoom = false;
		for (new i = 1; i <= MaxClients; i++)
		{
			PlayerHasEnteredStart[i] = false;
			if (FightOrDieTimer[i] != INVALID_HANDLE)
			{
				KillTimer(FightOrDieTimer[i]);
				FightOrDieTimer[i] = INVALID_HANDLE;
			}
		}
	}
	
}

public OnMapEnd()
{
	b_HasRoundStarted = false;
	b_HasRoundEnded = true;
	b_LeftSaveRoom = false;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (FightOrDieTimer[i] != INVALID_HANDLE)
		{
			KillTimer(FightOrDieTimer[i]);
			FightOrDieTimer[i] = INVALID_HANDLE;
		}
	}
}

public Action:PlayerLeftStart(Handle:Timer)
{
	if (LeftStartArea())
	{	
		if (!b_LeftSaveRoom)
		{
			b_LeftSaveRoom = true;
			canSpawnBoomer = true;
			canSpawnSmoker = true;
			canSpawnHunter = true;
			canSpawnSpitter = true;
			canSpawnJockey = true;
			canSpawnCharger = true;
			InitialSpawn = true;
			CheckIfBotsNeeded(false, true);
			CreateTimer(3.0, InitialSpawnReset, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	else
	{
		CreateTimer(1.0, PlayerLeftStart, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

public Action:InitialSpawnReset(Handle:Timer)
{
	InitialSpawn = false;
}

public Action:BotReadyReset(Handle:Timer)
{
	BotReady = 0;
}

public Action:InfectedBotBooterVersus(Handle:Timer)
{
	if (b_IsL4D2)
		return;
	new total;
	for (new i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == TEAM_INFECTED)
			{
				if (!IsPlayerTank(i) || (IsPlayerTank(i) && !PlayerIsAlive(i)))
				{
					total++;
				}
			}
		}
	}
	if (total + InfectedBotQueue > MaxPlayerZombies)
	{
		new kick = total + InfectedBotQueue - MaxPlayerZombies; 
		new kicked = 0;
		for (new i=1;(i<=MaxClients)&&(kicked < kick);i++)
		{
			if (IsClientInGame(i) && IsFakeClient(i))
			{
				if (GetClientTeam(i) == TEAM_INFECTED)
				{
					if (!IsPlayerTank(i) || ((IsPlayerTank(i) && !PlayerIsAlive(i))))
					{
						CreateTimer(0.1,kickbot,i);
						kicked++;
					}
				}
			}
		}
	}
	
}

public OnClientPutInServer(client)
{
	if (IsFakeClient(client))
		return;
	PlayersInServer++;
}
/*
public Action:evtPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	// We get the client id and time
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	// If client is valid
	if (!client || !IsClientInGame(client)) return Plugin_Continue;
	
	if (!IsPlayerTank(client) && IsFakeClient(client))
	{
		if (FightOrDieTimer[client] != INVALID_HANDLE)
		{
			KillTimer(FightOrDieTimer[client]);
			FightOrDieTimer[client] = INVALID_HANDLE;
		}
		//CreateTimer(20.0, DisposeOfCowards, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}
public Action:DisposeOfCowards(Handle:timer, any:coward)
{
	if (IsClientInGame(coward) && IsFakeClient(coward) && GetClientTeam(coward) == TEAM_INFECTED && !IsPlayerTank(coward) && PlayerIsAlive(coward))
	{
		if (IsPlayerSmoker(coward) && !IsVisibleToSurvivors(coward) && GetEntPropEnt(coward, Prop_Send, "m_tongueVictim") < 1)
		{
			CreateTimer(0.1,kickbot, coward);
		}
		else if (IsPlayerBoomer(coward) && !IsVisibleToSurvivors(coward))
		{
			CreateTimer(0.1,kickbot, coward);
		}
		else if (IsPlayerHunter(coward) && !IsVisibleToSurvivors(coward))
		{
			CreateTimer(0.1,kickbot, coward);
		}
		else if (IsPlayerSpitter(coward) && !IsVisibleToSurvivors(coward))
		{
			CreateTimer(0.1,kickbot, coward);
		}
		else if (IsPlayerJockey(coward) && !IsVisibleToSurvivors(coward) && GetEntPropEnt(coward, Prop_Send, "m_jockeyVictim") < 1  )
		{
			CreateTimer(0.1,kickbot, coward);
		}
		else if (IsPlayerCharger(coward) && !IsVisibleToSurvivors(coward))
		{
			CreateTimer(0.1,kickbot, coward);
		}
	}
	FightOrDieTimer[coward] = INVALID_HANDLE;
}
*/
public Action:Timer_SetUpBotGhost(Handle:timer, any:client)
{
	if (IsValidEntity(client))
	{
		if (!AlreadyGhostedBot[client])
		{
			SetGhostStatus(client, true);
			SetEntityMoveType(client, MOVETYPE_NONE);
			CreateTimer(GetConVarFloat(h_BotGhostTime), Timer_RestoreBotGhost, client, TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		AlreadyGhostedBot[client] = false;
	}
}

public Action:Timer_RestoreBotGhost(Handle:timer, any:client)
{
	if (IsValidEntity(client))
	{
		SetGhostStatus(client, false);
		SetEntityMoveType(client, MOVETYPE_WALK);
	}
}

public Action:evtPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (b_HasRoundEnded || !b_LeftSaveRoom) return Plugin_Continue;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (FightOrDieTimer[client] != INVALID_HANDLE)
	{
		KillTimer(FightOrDieTimer[client]);
		FightOrDieTimer[client] = INVALID_HANDLE;
	}
	if (!client || !IsClientInGame(client)) return Plugin_Continue;
	if (GetClientTeam(client) !=TEAM_INFECTED) return Plugin_Continue;
	if (GetEventBool(event, "victimisbot") && (!DirectorSpawn))
	{
		if (!IsPlayerTank(client))
		{
			new SpawnTime = GetURandomIntRange(InfectedSpawnTimeMin, InfectedSpawnTimeMax);
			if (AdjustSpawnTimes && MaxPlayerZombies != HumansOnInfected())
				SpawnTime = SpawnTime / (MaxPlayerZombies - HumansOnInfected());
			CreateTimer(float(SpawnTime), Spawn_InfectedBot, _, 0);
			InfectedBotQueue++;
		}
	}
	if (IsPlayerTank(client))
		CheckIfBotsNeeded(false, false);
	return Plugin_Continue;
}

public Action:Spawn_InfectedBot_Director(Handle:timer, any:BotNeeded)
{
	new bool:resetGhost[MAXPLAYERS+1];
	new bool:resetLife[MAXPLAYERS+1];
	
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && (!IsFakeClient(i)))
		{
			if (GetClientTeam(i)==TEAM_INFECTED)
			{
				if (IsPlayerGhost(i))
				{
					resetGhost[i] = true;
					SetGhostStatus(i, false);
				}
				else if (!PlayerIsAlive(i))
				{
					AlreadyGhosted[i] = false;
					SetLifeState(i, true);
				}
			}
		}
	}
	
	new anyclient = GetAnyClient();
	new bool:temp = false;
	if (anyclient == -1)
	{
		anyclient = CreateFakeClient("Bot");
		temp = true;
	}
	switch (BotNeeded)
	{
		case 1:
		CheatCommand(anyclient, "z_spawn_old", "smoker auto");
		case 2:
		CheatCommand(anyclient, "z_spawn_old", "boomer auto");
		case 3:
		CheatCommand(anyclient, "z_spawn_old", "hunter auto");
		case 4:
		CheatCommand(anyclient, "z_spawn_old", "spitter auto");
		case 5:
		CheatCommand(anyclient, "z_spawn_old", "jockey auto");
		case 6:
		CheatCommand(anyclient, "z_spawn_old", "charger auto");
	}
	for (new i=1;i<=MaxClients;i++)
	{
		if (resetGhost[i])
			SetGhostStatus(i, true);
		if (resetLife[i])
			SetLifeState(i, true);
	}
	if (temp) CreateTimer(0.1, kickbot, anyclient);
}

public Action:evtPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetEventBool(event, "isbot")) return Plugin_Continue;
	new newteam = GetEventInt(event, "team");
	new oldteam = GetEventInt(event, "oldteam");
	if (!b_HasRoundEnded && b_LeftSaveRoom && GameMode == 2)
	{
		if (oldteam == 3||newteam == 3)
		{
			CheckIfBotsNeeded(false, false);
		}
		if (newteam == 3)
		{
			CreateTimer(1.0, InfectedBotBooterVersus, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return Plugin_Continue;
}

public OnClientDisconnect(client)
{
	if (IsFakeClient(client))
		return;
	PlayerLifeState[client] = false;
	GetSpawnTime[client] = 0;
	AlreadyGhosted[client] = false;
	PlayerHasEnteredStart[client] = false;
	PlayersInServer--;
	if (PlayersInServer == 0)
	{
		b_LeftSaveRoom = false;
		b_HasRoundEnded = true;
		b_HasRoundStarted = false;
		for (new i = 1; i <= MaxClients; i++)
		{
			AlreadyGhosted[i] = false;
			PlayerHasEnteredStart[i] = false;
		}
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (FightOrDieTimer[i] != INVALID_HANDLE)
			{
				KillTimer(FightOrDieTimer[i]);
				FightOrDieTimer[i] = INVALID_HANDLE;
			}
		}
	}
	
}

public Action:CheckIfBotsNeededLater (Handle:timer, any:spawn_immediately)
{
	CheckIfBotsNeeded(spawn_immediately, false);
}

CheckIfBotsNeeded(bool:spawn_immediately, bool:initial_spawn)
{
	if (!DirectorSpawn)
	{
		if (b_HasRoundEnded || !b_LeftSaveRoom) return;
		CountInfected();
		new diff = MaxPlayerZombies - (InfectedBotCount + InfectedRealCount + InfectedBotQueue);
		if (diff > 0)
		{
			for (new i;i<diff;i++)
			{
				if (spawn_immediately)
				{
					InfectedBotQueue++;
					CreateTimer(0.5, Spawn_InfectedBot, _, 0);
				}
				else if (initial_spawn)
				{
					InfectedBotQueue++;
					CreateTimer(float(InitialSpawnInt), Spawn_InfectedBot, _, 0);
				}
				else
				{
					InfectedBotQueue++;
					if (GameMode == 2 && AdjustSpawnTimes && MaxPlayerZombies != HumansOnInfected())
						CreateTimer(float(InfectedSpawnTimeMax) / (MaxPlayerZombies - HumansOnInfected()), Spawn_InfectedBot, _, 0);
					else if (GameMode == 1 && AdjustSpawnTimes)
						CreateTimer(float(InfectedSpawnTimeMax - TrueNumberOfSurvivors()), Spawn_InfectedBot, _, 0);
					else
					CreateTimer(float(InfectedSpawnTimeMax), Spawn_InfectedBot, _, 0);
				}
			}
		}	
	}
}
CountInfected()
{
	InfectedBotCount = 0;
	InfectedRealCount = 0;
	for (new i=1;i<=MaxClients;i++)
	{
		if (!IsClientInGame(i)) continue;
		if (GetClientTeam(i) == TEAM_INFECTED)
		{
			if (IsFakeClient(i))
				InfectedBotCount++;
			else
			InfectedRealCount++;
		}
	}
	
}
public Action:evtFinaleStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(1.0, CheckIfBotsNeededLater, true);
}
BotTimePrepare()
{
	CreateTimer(1.0, BotTypeTimer)
	return 0;
}
public Action:BotTypeTimer (Handle:timer)
{
	BotTypeNeeded()
}
BotTypeNeeded()
{
	new boomers=0;
	new smokers=0;
	new hunters=0;
	new spitters=0;
	new jockeys=0;
	new chargers=0;
	new tanks=0;
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == TEAM_INFECTED && PlayerIsAlive(i))
			{
				if (IsPlayerSmoker(i))
					smokers++;
				else if (IsPlayerBoomer(i))
					boomers++;	
				else if (IsPlayerHunter(i))
					hunters++;	
				else if (IsPlayerTank(i))
					tanks++;	
				else if (b_IsL4D2 && IsPlayerSpitter(i))
					spitters++;	
				else if (b_IsL4D2 && IsPlayerJockey(i))
					jockeys++;	
				else if (b_IsL4D2 && IsPlayerCharger(i))
					chargers++;	
			}
		}
	}
	if  (b_IsL4D2)
	{
		new random = GetURandomIntRange(1, 7);
		
		if (random == 2)
		{
			if ((smokers < SmokerLimit) && (canSpawnSmoker))
			{
				return 2;
			}
		}
		else if (random == 3)
		{
			if ((boomers < BoomerLimit) && (canSpawnBoomer))
			{
				return 3;
			}
		}
		else if (random == 1)
		{
			if ((hunters < HunterLimit) && (canSpawnHunter))
			{
				return 1;
			}
		}
		else if (random == 4)
		{
			if ((spitters < SpitterLimit) && (canSpawnSpitter))
			{
				return 4;
			}
		}
		else if (random == 5)
		{
			if ((jockeys < JockeyLimit) && (canSpawnJockey))
			{
				return 5;
			}
		}
		else if (random == 6)
		{
			if ((chargers < ChargerLimit) && (canSpawnCharger))
			{
				return 6;
			}
		}
		
		else if (random == 7)
		{
			if (tanks < TankLimit)
			{
				return 7;
			}
		}
		return BotTimePrepare();
	}
	else
	{
		new random = GetURandomIntRange(1, 4);
		
		if (random == 2)
		{
			if ((smokers < SmokerLimit) && (canSpawnSmoker)) // we need a smoker ???? can we spawn a smoker ??? is smoker bot allowed ??
			{
				return 2;
			}
		}
		else if (random == 3)
		{
			if ((boomers < BoomerLimit) && (canSpawnBoomer))
			{
				return 3;
			}
		}
		else if (random == 1)
		{
			if (hunters < HunterLimit && canSpawnHunter)
			{
				return 1;
			}
		}
		
		else if (random == 4)
		{
			if (tanks < GetConVarInt(h_TankLimit))
			{
				return 7;
			}
		}
		
		return BotTimePrepare();
	}
}

public Action:Spawn_InfectedBot(Handle:timer)
{
	if (b_HasRoundEnded || !b_HasRoundStarted || !b_LeftSaveRoom) return;
	new Infected = MaxPlayerZombies;
	if (Coordination && !DirectorSpawn && !InitialSpawn)
	{
		BotReady++;
		for (new i=1;i<=MaxClients;i++)
		{
			if (!IsClientInGame(i)) continue;
			if (GetClientTeam(i)==TEAM_INFECTED)
			{
				if (!IsFakeClient(i))
					Infected--;
			}
		}
		if (BotReady >= Infected)
		{
			CreateTimer(3.0, BotReadyReset, _, TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			InfectedBotQueue--;
			return;
		}
	}
	CountInfected();
	if ((InfectedRealCount + InfectedBotCount) >= MaxPlayerZombies || (InfectedRealCount + InfectedBotCount + InfectedBotQueue) > MaxPlayerZombies) 	
	{
		InfectedBotQueue--;
		return;
	}
	if (DisableSpawnsTank)
	{
		for (new i=1;i<=MaxClients;i++)
		{
			if (!IsClientInGame(i)) continue;
			if (GetClientTeam(i)==TEAM_INFECTED)
			{
				if (IsPlayerTank(i) && IsPlayerAlive(i))
				{
					InfectedBotQueue--;
					return;
				}
			}
		}
		
	}
	new bool:resetGhost[MAXPLAYERS+1];
	new bool:resetLife[MAXPLAYERS+1];
	
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (GetClientTeam(i) == TEAM_INFECTED)
			{
				if (IsPlayerGhost(i))
				{
					resetGhost[i] = true;
					SetGhostStatus(i, false);
				}
				else if (!PlayerIsAlive(i))
				{
					resetLife[i] = true;
					SetLifeState(i, false);
				}
			}
		}
	}
	new anyclient = GetAnyClient();
	new bool:temp = false;
	if (anyclient == -1)
	{
		anyclient = CreateFakeClient("Bot");
		if (!anyclient)
		{
			return;
		}
		temp = true;
	}
	
	if (b_IsL4D2 && GameMode != 2)
	{
		new bot = CreateFakeClient("Infected Bot");
		if (bot != 0)
		{
			ChangeClientTeam(bot,TEAM_INFECTED);
			CreateTimer(0.1,kickbot,bot);
		}
	}
	new bot_type = BotTypeNeeded();
	switch (bot_type)
	{
		case 0:
		{
		}
		case 1:
		{
			CheatCommand(anyclient, "z_spawn", "hunter auto");
		}
		case 2:
		{	
			CheatCommand(anyclient, "z_spawn", "smoker auto");
		}
		case 3:
		{
			CheatCommand(anyclient, "z_spawn", "boomer auto");
		}
		case 4:
		{
			CheatCommand(anyclient, "z_spawn", "spitter auto");
		}
		case 5:
		{
			CheatCommand(anyclient, "z_spawn", "jockey auto");
		}
		case 6:
		{
			CheatCommand(anyclient, "z_spawn", "charger auto");
		}
		case 7:
		{
			CheatCommand(anyclient, "z_spawn", "tank auto");
		}
	}
	for (new i=1;i<=MaxClients;i++)
	{
		if (resetGhost[i] == true)
			SetGhostStatus(i, true);
		if (resetLife[i] == true)
			SetLifeState(i, true);
	}
	if (temp) CreateTimer(0.1,kickbot,anyclient);
	InfectedBotQueue--;
	CreateTimer(1.0, CheckIfBotsNeededLater, true);
}

stock GetAnyClient() 
{ 
	for (new target = 1; target <= MaxClients; target++) 
	{ 
		if (IsClientInGame(target)) return target; 
	} 
	return -1; 
} 

public Action:kickbot(Handle:timer, any:client)
{
	if (IsClientInGame(client) && (!IsClientInKickQueue(client)))
	{
		if (IsFakeClient(client)) KickClient(client);
	}
}

bool:IsPlayerGhost (client)
{
	if (GetEntProp(client, Prop_Send, "m_isGhost"))
		return true;
	return false;
}

bool:PlayerIsAlive (client)
{
	if (!GetEntProp(client,Prop_Send, "m_lifeState"))
		return true;
	return false;
}

bool:IsPlayerSmoker (client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_SMOKER)
		return true;
	return false;
}

bool:IsPlayerBoomer (client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_BOOMER)
		return true;
	return false;
}

bool:IsPlayerHunter (client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_HUNTER)
		return true;
	return false;
}

bool:IsPlayerSpitter (client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_SPITTER)
		return true;
	return false;
}

bool:IsPlayerJockey (client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_JOCKEY)
		return true;
	return false;
}

bool:IsPlayerCharger (client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_CHARGER)
		return true;
	return false;
}

bool:IsPlayerTank (client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_TANK)
		return true;
	return false;
}

SetGhostStatus (client, bool:ghost)
{
	if (ghost)
		SetEntProp(client, Prop_Send, "m_isGhost", 1);
	else
	SetEntProp(client, Prop_Send, "m_isGhost", 0);
}

SetLifeState (client, bool:ready)
{
	if (ready)
		SetEntProp(client, Prop_Send,  "m_lifeState", 1);
	else
	SetEntProp(client, Prop_Send, "m_lifeState", 0);
}

TrueNumberOfSurvivors ()
{
	new TotalSurvivors;
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i))
			if (GetClientTeam(i) == TEAM_SURVIVORS)
				TotalSurvivors++;
		}
	return TotalSurvivors;
}

HumansOnInfected ()
{
	new TotalHumans;
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && !IsFakeClient(i))
			TotalHumans++;
	}
	return TotalHumans;
}

bool:LeftStartArea()
{
	new ent = -1, maxents = GetMaxEntities();
	for (new i = MaxClients+1; i <= maxents; i++)
	{
		if (IsValidEntity(i))
		{
			decl String:netclass[64];
			GetEntityNetClass(i, netclass, sizeof(netclass));
			
			if (StrEqual(netclass, "CTerrorPlayerResource"))
			{
				ent = i;
				break;
			}
		}
	}
	
	if (ent > -1)
	{
		if (GetEntProp(ent, Prop_Send, "m_hasAnySurvivorLeftSafeArea"))
		{
			return true;
		}
	}
	return false;
}

stock GetURandomIntRange(min, max)
{
	return (GetURandomInt() % (max-min+1)) + min;
}

stock CheatCommand(client, String:command[], String:arguments[] = "")
{
	new userFlags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userFlags);
}
stock bool:IsVisibleToSurvivors(entity)
{
	new iSurv;
	for (new i = 1; i <= MaxClients && iSurv < 5; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			iSurv++;
			if (IsPlayerAlive(i) && IsVisibleTo(i, entity))
			{
				return true;
			}
		}
	}
	return false;
}

stock bool:IsVisibleTo(client, entity)
{
	decl Float:vAngles[3], Float:vOrigin[3], Float:vEnt[3], Float:vLookAt[3];
	GetClientEyePosition(client,vOrigin);
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vEnt);
	MakeVectorFromPoints(vOrigin, vEnt, vLookAt);
	GetVectorAngles(vLookAt, vAngles);
	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceFilter);
	new bool:isVisible = false;
	if (TR_DidHit(trace))
	{
		decl Float:vStart[3];
		TR_GetEndPosition(vStart, trace);
		
		if ((GetVectorDistance(vOrigin, vStart, false) + TRACE_TOLERANCE) >= GetVectorDistance(vOrigin, vEnt))
		{
			isVisible = true;
		}
	}
	else
	{
		isVisible = true;
	}
	CloseHandle(trace);
	return isVisible;
}

public bool:TraceFilter(entity, contentsMask)
{
	if (entity <= MaxClients || !IsValidEntity(entity))
	{
		return false;
	}
	decl String:class[128];
	GetEdictClassname(entity, class, sizeof(class));
	if (StrEqual(class, CLASSNAME_INFECTED, .caseSensitive = false)
	|| StrEqual(class, CLASSNAME_WITCH, .caseSensitive = false) 
	|| StrEqual(class, CLASSNAME_PHYSPROPS, .caseSensitive = false))
	{
		return false;
	}
	return true;
}
stock bool:IsInfectedGhost(client) 
{
    return bool:GetEntProp(client, Prop_Send, "m_isGhost");
}