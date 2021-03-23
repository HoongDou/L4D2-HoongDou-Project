#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#define CVAR_FLAGS			FCVAR_NOTIFY

ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarChance1, g_hCvarChance2, g_hCvarChance3, g_hCvarSize, g_hCvarSpeed;// g_hCvarSizeStart
int g_iCvarChance1, g_iCvarChance2, g_iCvarChance3, g_iTotalChance;
bool g_bCvarAllow, g_bMapStarted;
bool g_bWeaponHandling;
float g_fCvarSize, g_fCvarSpeed, g_fRewarded[MAXPLAYERS + 1];// g_fCvarSizeStart

enum L4D2WeaponType 
{
	L4D2WeaponType_Unknown = 0,
	L4D2WeaponType_Pistol,
	L4D2WeaponType_Magnum,
	L4D2WeaponType_Rifle,
	L4D2WeaponType_RifleAk47,
	L4D2WeaponType_RifleDesert,
	L4D2WeaponType_RifleM60,
	L4D2WeaponType_RifleSg552,
	L4D2WeaponType_HuntingRifle,
	L4D2WeaponType_SniperAwp,
	L4D2WeaponType_SniperMilitary,
	L4D2WeaponType_SniperScout,
	L4D2WeaponType_SMG,
	L4D2WeaponType_SMGSilenced,
	L4D2WeaponType_SMGMp5,
	L4D2WeaponType_Autoshotgun,
	L4D2WeaponType_AutoshotgunSpas,
	L4D2WeaponType_Pumpshotgun,
	L4D2WeaponType_PumpshotgunChrome,
	L4D2WeaponType_Molotov,
	L4D2WeaponType_Pipebomb,
	L4D2WeaponType_FirstAid,
	L4D2WeaponType_Pills,
	L4D2WeaponType_Gascan,
	L4D2WeaponType_Oxygentank,
	L4D2WeaponType_Propanetank,
	L4D2WeaponType_Vomitjar,
	L4D2WeaponType_Adrenaline,
	L4D2WeaponType_Chainsaw,
	L4D2WeaponType_Defibrilator,
	L4D2WeaponType_GrenadeLauncher,
	L4D2WeaponType_Melee,
	L4D2WeaponType_UpgradeFire,
	L4D2WeaponType_UpgradeExplosive,
	L4D2WeaponType_BoomerClaw,
	L4D2WeaponType_ChargerClaw,
	L4D2WeaponType_HunterClaw,
	L4D2WeaponType_JockeyClaw,
	L4D2WeaponType_SmokerClaw,
	L4D2WeaponType_SpitterClaw,
	L4D2WeaponType_TankClaw
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnLibraryAdded(const char[] name)
{
	if( strcmp(name, "WeaponHandling") == 0 )
		g_bWeaponHandling = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if( strcmp(name, "WeaponHandling") == 0 )
		g_bWeaponHandling = false;
}

GF_PluginStart()
{
	// ====================================================================================================
	// CVARS
	// ====================================================================================================
	g_hCvarAllow = CreateConVar(		"l4d2_gift_rewards_allow",			"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarChance1 = CreateConVar(		"l4d2_gift_rewards_chance_ammo",	"100",			"Chance to completely refill a players ammo.", CVAR_FLAGS );
	g_hCvarChance2 = CreateConVar(		"l4d2_gift_rewards_chance_heal",	"100",			"Chance to restore a players health to full.", CVAR_FLAGS );
	g_hCvarChance3 = CreateConVar(		"l4d2_gift_rewards_chance_speed",	"100",			"Chance to reward increased speed for: shooting, reloading and deploying. Requires WeaponHandling API plugin.", CVAR_FLAGS );
	g_hCvarSize = CreateConVar(			"l4d2_gift_rewards_size",			"0.0",			"0.0=Off. Reduces the size of gifts over this many seconds.", CVAR_FLAGS );
	// g_hCvarSizeStart = CreateConVar(	"l4d2_gift_rewards_size_start",		"2.0",			"1.0=Default. Starting size of the gift.", CVAR_FLAGS ); // Unused, glow appears wrong, here for reference if someone wants to test.
	g_hCvarSpeed = CreateConVar(		"l4d2_gift_rewards_speed",			"20.0",			"Duration the increased speed affects a player.", CVAR_FLAGS );
	g_hCvarModes = CreateConVar(		"l4d2_gift_rewards_modes",			"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(		"l4d2_gift_rewards_modes_off",		"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(		"l4d2_gift_rewards_modes_tog",		"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarChance1.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarChance2.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarChance3.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSize.AddChangeHook(ConVarChanged_Cvars);
	// g_hCvarSizeStart.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSpeed.AddChangeHook(ConVarChanged_Cvars);
}


public void OnMapEnd()
{
	g_bMapStarted = false;
	ResetPlugin();
}

void ResetPlugin()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		g_fRewarded[i] = 0.0;
	}
}

public void OnMapStart()
{
	g_bMapStarted = true;
	// PrecacheSound(SOUND_DROP);
}





// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnConfigsExecuted()
{
	IsAllowed();
}

public void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	// g_fCvarSizeStart = g_hCvarSizeStart.FloatValue;
	g_fCvarSize = g_hCvarSize.FloatValue;
	g_fCvarSpeed = g_hCvarSpeed.FloatValue;

	g_iTotalChance = 0;
	g_iCvarChance1 = GetChance(g_hCvarChance1);
	g_iCvarChance2 = GetChance(g_hCvarChance2);
	if( g_bWeaponHandling )
		g_iCvarChance3 = GetChance(g_hCvarChance3);
}

int GetChance(ConVar cvar)
{
	int rtn = cvar.IntValue;
	if( rtn )
	{
		g_iTotalChance += rtn;
		rtn = g_iTotalChance;
	}
	return rtn;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		HookEvent("christmas_gift_grab",		EventGift);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		UnhookEvent("christmas_gift_grab",		EventGift);
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if( iCvarModesTog != 0 )
	{
		if( g_bMapStarted == false )
			return false;

		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		if( IsValidEntity(entity) )
		{
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "PostSpawnActivate");
			if( IsValidEntity(entity) ) // Because sometimes "PostSpawnActivate" seems to kill the ent.
				RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
		}

		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
public void OnEntityCreated(int entity, const char[] classname)
{
	// if( g_bCvarAllow && (g_fCvarSize || g_fCvarSizeStart) && strcmp(classname, "holiday_gift") == 0 )
	if( g_bCvarAllow && g_fCvarSize && strcmp(classname, "holiday_gift") == 0 )
	{
		// if( g_fCvarSizeStart )
			// SetEntPropFloat(entity, Prop_Send, "m_flModelScale", g_fCvarSizeStart);

		// if( g_fCvarSize )
		CreateTimer(0.1, TimerSize, EntIndexToEntRef(entity), TIMER_REPEAT);
	}
}

public Action TimerSize(Handle timer, any entity)
{
	if( EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
	{
		float scale = GetEntPropFloat(entity, Prop_Send, "m_flModelScale") - (1.0 / g_fCvarSize / 10);
		if( scale > 0.1 )
			SetEntPropFloat(entity, Prop_Send, "m_flModelScale", scale);
		else
			return Plugin_Stop;

		return Plugin_Continue;
	}
	return Plugin_Stop;
}

public void EventGift(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	GiveAward(client);
}

void GiveAward(int client)
{
	if( GetClientTeam(client) == 2 )
	{
		int random = GetRandomInt(1, g_iTotalChance);
		// PrintToServer("Reward random %d/%d (%d %d %d)", random, g_iTotalChance, g_iCvarChance1, g_iCvarChance2, g_iCvarChance3);

		if(			g_iCvarChance1 && random <= g_iCvarChance1 )		random = 1;
		else if(	g_iCvarChance2 && random <= g_iCvarChance2 )		random = 2;
		else if(	g_iCvarChance3 && random <= g_iCvarChance3 )		random = 3;
		else random = 0;
		// PrintToServer("Reward chosen %d", random);

		if( random )
		{
			switch( random )
			{
				case 1:		RefillAmmo(client);
				case 2:		HealPlayer(client);
				case 3:		g_fRewarded[client] = GetGameTime() + g_fCvarSpeed;
			}
		}
	}
}

void RefillAmmo(int client)
{
	int a = GetRandomInt(1, 10);
	player_data[client][MONEY] += a;
	PrintToChatAll("\x04%N\x03打开了礼包获得%d点B数", client,a);
}

void HealPlayer(int client)
{
	int b = GetRandomInt(1, 1000);
    player_data[client][EXPERIENCE] += b;
	PrintToChatAll("\x04%N\x03打开了礼包获得%d点经验", client,b);
}



// ====================================================================================================
//					WEAPON HANDLING
// ====================================================================================================
public void WH_OnMeleeSwing(int client, int weapon, float &speedmodifier)
{
	speedmodifier = SpeedModifier(client, speedmodifier); //send speedmodifier to be modified
}

public void WH_OnStartThrow(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier = SpeedModifier(client, speedmodifier);
}

public void WH_OnReadyingThrow(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier = SpeedModifier(client, speedmodifier);
}

public void WH_OnReloadModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier = SpeedModifier(client, speedmodifier);
}

public void WH_OnGetRateOfFire(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier = SpeedModifier(client, speedmodifier);
}

public void WH_OnDeployModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier = SpeedModifier(client, speedmodifier);
}

float SpeedModifier(int iClient, float speedmodifier)
{
	if( g_fRewarded[iClient] > GetGameTime() )
	{
		speedmodifier = speedmodifier * 1.5;// multiply current modifier to not overwrite any existing modifiers already
	}
	return speedmodifier;
}



// ====================================================================================================
//					POSITION
// ====================================================================================================
bool SetTeleportEndPoint(int client, float vPos[3], float vAng[3])
{
	GetClientEyePosition(client, vPos);
	GetClientEyeAngles(client, vAng);

	Handle trace = TR_TraceRayFilterEx(vPos, vAng, MASK_SHOT, RayType_Infinite, _TraceFilter);

	if( TR_DidHit(trace) )
	{
		float vNorm[3];
		TR_GetEndPosition(vPos, trace);
		TR_GetPlaneNormal(trace, vNorm);
		float angle = vAng[1];
		GetVectorAngles(vNorm, vAng);

		if( vNorm[2] == 1.0 )
		{
			vAng[0] = 0.0;
			vAng[1] += angle;
		}
		else
		{
			vAng[0] = 0.0;
			vAng[1] += angle - 90.0;
		}
	}
	else
	{
		delete trace;
		return false;
	}

	delete trace;
	return true;
}

public bool _TraceFilter(int entity, int contentsMask)
{
	return entity > MaxClients || !entity;
}