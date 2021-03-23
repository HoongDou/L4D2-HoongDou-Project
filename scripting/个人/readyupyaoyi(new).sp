#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#include <left4dhooks>
//#include <left4downtown>
//#include <l4d2_direct>
#include <builtinvotes>
#include <colors>

#define MAX_FOOTERS 10
#define MAX_FOOTER_LEN 65
#define MAX_SOUNDS 5

#define DEBUG 0

#pragma newdecls required

public Plugin myinfo =
{
	name = "L4D2 Ready-Up with convenience fixes",
	author = "CanadaRox, Harry Potter,Target",
	description = "New and improved ready-up plugin with convenience fixes.",
	version = "new v1.1",
	url = "https://github.com/fbef0102 https://github.com/melt5150"
};

enum L4D2_Team
{
	L4D2Team_Spectator = 1,
	L4D2Team_Survivor,
	L4D2Team_Infected
}

// Plugin Cvars
ConVar l4d_ready_enabled;
ConVar l4d_ready_disable_spawns;
ConVar l4d_ready_cfg_name;
ConVar l4d_ready_survivor_freeze;
ConVar l4d_ready_max_players;
ConVar l4d_ready_delay;
ConVar l4d_ready_enable_sound;
ConVar l4d_ready_chuckle;
ConVar l4d_ready_countdown_sound;
ConVar l4d_ready_live_sound;

Handle g_hVote;
float g_fButtonTime[MAXPLAYERS + 1];
int g_vecLastMouse[MAXPLAYERS + 1][2];

// Game Cvars
ConVar director_no_specials;
ConVar god;
ConVar sb_stop;
ConVar survivor_limit;
//ConVar z_max_player_zombies;
ConVar sv_infinite_primary_ammo;
ConVar ServerNamer;

StringMap casterTrie;
Handle liveForward;
Panel menuPanel;
Handle readyCountdownTimer;
char readyFooter[MAX_FOOTERS][MAX_FOOTER_LEN];
bool hiddenPanel[MAXPLAYERS + 1];
bool inLiveCountdown = false;
bool inReadyUp;
bool isPlayerReady[MAXPLAYERS + 1];
int footerCounter = 0;
int readyDelay;
char countdownSound[256];
char liveSound[256];

bool bSkipWarp;
bool blockSecretSpam[MAXPLAYERS + 1];

int iCmd;
char sCmd[MAX_NAME_LENGTH];

//ConVar allowedCastersTrie;
float g_fTime;

char chuckleSound[MAX_SOUNDS][] =
{
	"/npc/moustachio/strengthattract01.wav",
	"/npc/moustachio/strengthattract02.wav",
	"/npc/moustachio/strengthattract05.wav",
	"/npc/moustachio/strengthattract06.wav",
	"/npc/moustachio/strengthattract09.wav"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("AddStringToReadyFooter", Native_AddStringToReadyFooter);
	CreateNative("EditFooterStringAtIndex", Native_EditFooterStringAtIndex);
	CreateNative("FindIndexOfFooterString", Native_FindIndexOfFooterString);
	CreateNative("GetFooterStringAtIndex", Native_GetFooterStringAtIndex);
	CreateNative("IsInReady", Native_IsInReady);
	CreateNative("IsClientCaster", Native_IsClientCaster);
	CreateNative("IsIDCaster", Native_IsIDCaster);
	liveForward = CreateGlobalForward("OnRoundIsLive", ET_Event);
	RegPluginLibrary("readyup");
	return APLRes_Success;
}

public void OnPluginStart()
{
	l4d_ready_enabled = CreateConVar("l4d_ready_enabled", "1", "This cvar doesn't do anything, but if it is 0 the logger wont log this game.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	l4d_ready_cfg_name = CreateConVar("l4d_ready_cfg_name", "", "Configname to display on the ready-up panel", FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	l4d_ready_disable_spawns = CreateConVar("l4d_ready_disable_spawns", "0", "Prevent SI from having spawns during ready-up", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	l4d_ready_survivor_freeze = CreateConVar("l4d_ready_survivor_freeze", "1", "Freeze the survivors during ready-up.  When unfrozen they are unable to leave the saferoom but can move freely inside", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	l4d_ready_max_players = CreateConVar("l4d_ready_max_players", "12", "Maximum number of players to show on the ready-up panel.", FCVAR_NOTIFY, true, 0.0, true, MAXPLAYERS+1.0);
	l4d_ready_delay = CreateConVar("l4d_ready_delay", "5", "Number of seconds to count down before the round goes live.", FCVAR_NOTIFY, true, 0.0);
	l4d_ready_enable_sound = CreateConVar("l4d_ready_enable_sound", "1", "Enable sound during countdown & on live");
	l4d_ready_countdown_sound = CreateConVar("l4d_ready_countdown_sound", "buttons/blip1.wav", "The sound that plays when a round goes on countdown");	
	l4d_ready_live_sound = CreateConVar("l4d_ready_live_sound", "buttons/blip2.wav", "The sound that plays when a round goes live");
	l4d_ready_chuckle = CreateConVar("l4d_ready_chuckle", "0", "Enable random moustachio chuckle during countdown");
	//l4d_ready_warp_team = CreateConVar("l4d_ready_warp_team", "1", "Should we warp the entire team when a player attempts to leave saferoom?");
	l4d_ready_survivor_freeze.AddChangeHook(SurvFreezeChange);

	HookEvent("round_start", RoundStart_Event);
	HookEvent("player_team", PlayerTeam_Event);

	casterTrie = CreateTrie();
	//allowedCastersTrie = CreateTrie();

	director_no_specials = FindConVar("director_no_specials");
	god = FindConVar("god");
	sb_stop = FindConVar("sb_stop");
	survivor_limit = FindConVar("survivor_limit");
	//z_max_player_zombies = FindConVar("z_max_player_zombies");
	sv_infinite_primary_ammo = FindConVar("sv_infinite_primary_ammo");
	ServerNamer = FindConVar("sn_main_name");
	//z_max_player_zombies = 0;
	
	if (FindConVar("sn_main_name") != null) {
		ServerNamer = FindConVar("sn_main_name");
	} else {
		ServerNamer = FindConVar("hostname");
	}

	/* Ready Commands */
	RegConsoleCmd("sm_ready", Ready_Cmd, "Mark yourself as ready for the round to go live");
	RegConsoleCmd("sm_r", Ready_Cmd, "Mark yourself as ready for the round to go live");
	RegConsoleCmd("sm_toggleready", ToggleReady_Cmd, "Toggle your ready status");
	RegConsoleCmd("sm_unready", Unready_Cmd, "Mark yourself as not ready if you have set yourself as ready");
	RegConsoleCmd("sm_nr", Unready_Cmd, "Mark yourself as not ready if you have set yourself as ready");
	
	/* Cast Commands */
	RegAdminCmd("sm_caster", Caster_Cmd, ADMFLAG_BAN, "Registers a player as a caster so the round will not go live unless they are ready");
	RegConsoleCmd("sm_cast", Cast_Cmd, "Registers the calling player as a caster so the round will not go live unless they are ready");
	RegConsoleCmd("sm_notcasting", NotCasting_Cmd, "Deregister yourself as a caster or allow admins to deregister other players");
	RegConsoleCmd("sm_uncast", NotCasting_Cmd, "Deregister yourself as a caster or allow admins to deregister other players");
	
	/* Player Commands */
	RegConsoleCmd("sm_forcestart", ForceStart_Cmd, "Forces the round to start regardless of player ready status.  Players can unready to stop a force");
	RegConsoleCmd("sm_fs", ForceStart_Cmd, "Forces the round to start regardless of player ready status.  Players can unready to stop a force");
	RegConsoleCmd("sm_hide", Hide_Cmd, "Hides the ready-up panel so other menus can be seen");
	RegConsoleCmd("sm_show", Show_Cmd, "Shows a hidden ready-up panel");
	RegConsoleCmd("sm_return", Return_Cmd, "Return to a valid saferoom spawn if you get stuck during an unfrozen ready-up period");
	RegConsoleCmd("sm_kickspecs", KickSpecs_Cmd, "Let's vote to kick those Spectators!");
	
	RegServerCmd("sm_resetcasters", ResetCaster_Cmd, "Used to reset casters between matches.  This should be in confogl_off.cfg or equivalent for your system");
	//RegServerCmd("sm_add_caster_id", AddCasterSteamID_Cmd, "Used for adding casters to the whitelist -- i.e. who's allowed to self-register as a caster");

#if DEBUG
	RegAdminCmd("sm_initready", InitReady_Cmd, ADMFLAG_ROOT);
	RegAdminCmd("sm_initlive", InitLive_Cmd, ADMFLAG_ROOT);
#endif

	AddCommandListener(Say_Callback, "say");
	AddCommandListener(Say_Callback, "say_team");
	AddCommandListener(Vote_Callback, "Vote");

	LoadTranslations("common.phrases");
	
	l4d_ready_enabled.AddChangeHook(OnEnabledChanged);
}

public Action Say_Callback(int client, char[] command, int args)
{
	SetEngineTime(client);
	return Plugin_Continue;
}

public Action Vote_Callback(int client, char[] command, int args)
{
	if (IsBuiltinVoteInProgress()) 
	{
		return Plugin_Continue;
	}

	char sArgs[32];
	GetCmdArg(1, sArgs, sizeof(sArgs));
	if (StrContains(sArgs, "Yes", false) != -1)
	{
		FakeClientCommandEx(client, "say /ready");
	}
	else FakeClientCommandEx(client, "say /unready");
	
	return Plugin_Continue;
}

public void OnPluginEnd()
{
	if (inReadyUp)
		InitiateLive(false);
}

public void OnEnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!GetConVarBool(l4d_ready_enabled))
	{
		CreateTimer(1.0, Timer_InitiateLive, _, TIMER_REPEAT);
	}
}

public Action Timer_InitiateLive(Handle timer)
{
	if (inReadyUp && !inLiveCountdown)
	{
		InitiateLiveCountdown();
		return Plugin_Handled;
	}
	return Plugin_Stop;
}

public void OnMapStart()
{
	/* OnMapEnd needs this to work */
	l4d_ready_countdown_sound.GetString(countdownSound, sizeof(countdownSound));
	l4d_ready_live_sound.GetString(liveSound, sizeof(liveSound));
	PrecacheSound("/level/gnomeftw.wav");
	PrecacheSound("/weapons/defibrillator/defibrillator_use.wav");
	PrecacheSound("/commentary/com-welcome.wav");
	PrecacheSound("weapons/hegrenade/beep.wav");
	PrecacheSound("/common/bugreporter_failed.wav");
	PrecacheSound("/level/loud/climber.wav");
	PrecacheSound("/player/survivor/voice/mechanic/ellisinterrupt07.wav");
	PrecacheSound("/npc/pilot/radiofinale08.wav");
	PrecacheSound(countdownSound);
	PrecacheSound(liveSound);
	for (int i = 0; i < MAX_SOUNDS; i++)
	{
		PrecacheSound(chuckleSound[i]);
	}
	for (int client = 1; client <= MAXPLAYERS; client++)
	{
		blockSecretSpam[client] = false;
	}
	readyCountdownTimer = null;
	
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	if (StrEqual(sMap, "dprm1_milltown_a", false)) {
		bSkipWarp = true;
	} else {
		bSkipWarp = false;
	}
}

/* This ensures all cvars are reset if the map is changed during ready-up */
public void OnMapEnd()
{
	if (inReadyUp)
		InitiateLive(false);
}

public void OnClientDisconnect(int client)
{
	hiddenPanel[client] = false;
	isPlayerReady[client] = false;
	g_fButtonTime[client] = 0.0;
	g_vecLastMouse[client][0] = 0;
	g_vecLastMouse[client][1] = 0;
}

public void SetEngineTime(int client)
{
	g_fButtonTime[client] = GetEngineTime();
}

public int Native_AddStringToReadyFooter(Handle plugin, int numParams)
{
	char footer[MAX_FOOTER_LEN];
	GetNativeString(1, footer, sizeof(footer));
	if (footerCounter < MAX_FOOTERS)
	{
		if (strlen(footer) < MAX_FOOTER_LEN)
		{
			strcopy(readyFooter[footerCounter], MAX_FOOTER_LEN, footer);
			footerCounter++;
			return _:footerCounter-1;
		}
	}
	return _:-1;
}

public int Native_EditFooterStringAtIndex(Handle plugin, int numParams)
{
	char newString[MAX_FOOTER_LEN];
	GetNativeString(2, newString, sizeof(newString));
	int index = GetNativeCell(1);
	
	if (footerCounter < MAX_FOOTERS)
	{
		if (strlen(newString) < MAX_FOOTER_LEN)
		{
			readyFooter[index] = newString;
			return _:true;
		}
	}
	return _:false;
}

public int Native_FindIndexOfFooterString(Handle plugin, int numParams)
{
	char stringToSearchFor[MAX_FOOTER_LEN];
	GetNativeString(1, stringToSearchFor, sizeof(stringToSearchFor));
	
	for (new i = 0; i < footerCounter; i++){
		if (StrEqual(readyFooter[i], "\0", true)) continue;
		
		if (StrContains(readyFooter[i], stringToSearchFor, false) > -1){
			return _:i;
		}
	}
	
	return _:-1;
}

public int Native_GetFooterStringAtIndex(Handle plugin, int numParams)
{
	int index = GetNativeCell(1);
	char buffer[65];
	GetNativeString(2, buffer, 65);
	
	
	if (index < MAX_FOOTERS) {
		buffer = readyFooter[index];
	} 
	
	SetNativeString(2, buffer, 65, true);
}

public int Native_IsInReady(Handle plugin, int numParams)
{
	return _:inReadyUp;
}

public int Native_IsClientCaster(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return _:IsClientCaster(client);
}

public int Native_IsIDCaster(Handle plugin, int numParams)
{
	char buffer[64];
	GetNativeString(1, buffer, sizeof(buffer));
	return _:IsIDCaster(buffer);
}

stock bool IsClientCaster(int client)
{
	char buffer[64];
	return GetClientAuthId(client, AuthId_Steam2, buffer, sizeof(buffer)) && IsIDCaster(buffer);
}

stock bool IsIDCaster(const char[] AuthID)
{
	any dummy;
	return GetTrieValue(casterTrie, AuthID, dummy);
}

public Action Cast_Cmd(int client, int args)
{	
 	char buffer[64];
	GetClientAuthId(client, AuthId_Steam2, buffer, sizeof(buffer));
	if (GetClientTeam(client) != 1)
	{
		ChangeClientTeam(client, 1);
	}
	casterTrie.SetValue(buffer, 1);
	CPrintToChat(client, "{blue}[{default}Cast{blue}] {default}You have registered yourself as a caster");
	CPrintToChat(client, "{blue}[{default}Cast{blue}] {default}Reconnect to make your Addons work.");
	return Plugin_Handled;
}

public Action Caster_Cmd(int client, int args)
{	
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_caster <player>");
		return Plugin_Handled;
	}
	
	char buffer[64];
	GetCmdArg(1, buffer, sizeof(buffer));
	
	int target = FindTarget(client, buffer, true, false);
	if (target > 0) // If FindTarget fails we don't need to print anything as it prints it for us!
	{
		if (GetClientAuthId(target, AuthId_Steam2, buffer, sizeof(buffer)))
		{
			casterTrie.SetValue(buffer, 1);
			ReplyToCommand(client, "Registered %N as a caster", target);
			CPrintToChat(target, "{blue}[{olive}!{blue}] {default}An Admin has registered you as a caster");
		}
		else
		{
			ReplyToCommand(client, "Couldn't find Steam ID.  Check for typos and let the player get fully connected.");
		}
	}
	return Plugin_Handled;
}

public Action ResetCaster_Cmd(int args)
{
	casterTrie.Clear();
	return Plugin_Handled;
}
/*
public Action:AddCasterSteamID_Cmd(args)
{
	decl String:buffer[128];
	GetCmdArg(1, buffer, sizeof(buffer));
	if (buffer[0] != EOS) 
	{
		new index = FindStringInArray(allowedCastersTrie, buffer);
		if (index == -1)
		{
			PushArrayString(allowedCastersTrie, buffer);
			PrintToServer("[casters_database] Added '%s'", buffer);
		}
		else PrintToServer("[casters_database] '%s' already exists", buffer);
	}
	else PrintToServer("[casters_database] No args specified / empty buffer");
	return Plugin_Handled;
}*/

public Action Hide_Cmd(int client, int args)
{
	hiddenPanel[client] = true;
	CPrintToChat(client, "[{olive}Readyup{default}] Ready-up Panel is now {red}hidden{default}.");
	return Plugin_Handled;
}

public Action Show_Cmd(int client, int args)
{
	hiddenPanel[client] = false;
	CPrintToChat(client, "[{olive}Readyup{default}] Ready-up Panel is now {blue}shown{default}.");
	return Plugin_Handled;
}

public Action NotCasting_Cmd(client, args)
{
	char buffer[64];
	
	if (args < 1) // If no target is specified
	{
		GetClientAuthId(client, AuthId_Steam2, buffer, sizeof(buffer));
		casterTrie.Remove(buffer);
		CPrintToChat(client, "{blue}[{default}Reconnect{blue}] {default}You will be reconnected to the server..");
		CPrintToChat(client, "{blue}[{default}Reconnect{blue}] {default}There's a black screen instead of a loading bar!");
		CreateTimer(3.0, Reconnect, client);
		return Plugin_Handled;
	}
	else // If a target is specified
	{
		AdminId id;
		id = GetUserAdmin(client);
		bool hasFlag = false;
		
		if (id != INVALID_ADMIN_ID)
		{
			hasFlag = GetAdminFlag(id, Admin_Ban); // Check for specific admin flag
		}
		
		if (!hasFlag)
		{
			ReplyToCommand(client, "Only admins can remove other casters. Use sm_notcasting without arguments if you wish to remove yourself.");
			return Plugin_Handled;
		}
		
		GetCmdArg(1, buffer, sizeof(buffer));
		
		int target = FindTarget(client, buffer, true, false);
		if (target > 0) // If FindTarget fails we don't need to print anything as it prints it for us!
		{
			if (GetClientAuthId(target, AuthId_Steam2, buffer, sizeof(buffer)))
			{
				casterTrie.Remove(buffer);
				ReplyToCommand(client, "%N is no longer a caster", target);
			}
			else
			{
				ReplyToCommand(client, "Couldn't find Steam ID.  Check for typos and let the player get fully connected.");
			}
		}
		return Plugin_Handled;
	}
}

public Action Reconnect(Handle timer, int client)
{
	if (IsClientConnected(client))
	{
		ReconnectClient(client);
	}
	return Plugin_Handled;
}

public Action ForceStart_Cmd(int client, int args)
{
	if (inReadyUp)
	{
		AdminId id;
		id = GetUserAdmin(client);
		bool hasFlag = false;
		
		if (id != INVALID_ADMIN_ID)
		{
			hasFlag = GetAdminFlag(id, Admin_Ban); // Check for specific admin flag
		}
		if (hasFlag)
		{
			InitiateLiveCountdown();
			CPrintToChatAll("[{green}!{default}] {blue}Game {default}is enforced to {green}Live {default}by {blue}Admin {olive}%N{default}", client);
			return Plugin_Handled;
		}
		
		int playercount;
		for (int i = 1; i < MaxClients; i++)
		{
			if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) && !IsClientObserver(i))
				playercount++;
		}
		
		if (playercount == GetConVarInt(survivor_limit)) //+ GetConVarInt(z_max_player_zombies))
		{
			CPrintToChat(client, "[{olive}Readyup{default}] No command abuse.");
			return Plugin_Handled;
		}
		
		if (!IsPlayer(client))
		{
			CPrintToChat(client, "[{olive}Readyup{default}] Spectator is not allowed to vote for Force Start.");
			return Plugin_Handled;
		}
		
		StartForceStartVote(client);
	}
	return Plugin_Handled;
}

public Action KickSpecs_Cmd(int client, int args)
{
	if (inReadyUp)
	{
		AdminId id;
		id = GetUserAdmin(client);
		bool hasFlag = false;
		
		if (id != INVALID_ADMIN_ID)
		{
			hasFlag = GetAdminFlag(id, Admin_Ban); // Check for specific admin flag
		}
		
		if (hasFlag)
		{
			CreateTimer(2.0, Timer_KickSpecs);
			CPrintToChatAll("[{green}!{default}] {blue}Spectators {default}are kicked by {blue}Admin {olive}%N{default}", client);
			return Plugin_Handled;
		}
		
		StartKickSpecsVote(client);
	}
	return Plugin_Handled;
}

public void StartForceStartVote(int client)
{
	if (!IsPlayer(client)) { return; }
	if (!IsNewBuiltinVoteAllowed()) { return; }
	
	g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

	char sBuffer[128];
	FormatEx(sBuffer, sizeof(sBuffer), "Enforce the Game to Live? (100%%)");
	SetBuiltinVoteArgument(g_hVote, sBuffer);
	SetBuiltinVoteInitiator(g_hVote, client);
	SetBuiltinVoteResultCallback(g_hVote, ForceStartVoteResultHandler);
	DisplayBuiltinVoteToAllNonSpectators(g_hVote, 20);

	FakeClientCommand(client, "Vote Yes");
}

public void StartKickSpecsVote(int client)
{
	if (!IsPlayer(client)) { return; }
	if (!IsNewBuiltinVoteAllowed()) { return; }
	
	g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

	char sBuffer[128];
	FormatEx(sBuffer, sizeof(sBuffer), "Kick All Non-Admin and Non-Casting Spectators?");
	SetBuiltinVoteArgument(g_hVote, sBuffer);
	SetBuiltinVoteInitiator(g_hVote, client);
	SetBuiltinVoteResultCallback(g_hVote, KickSpecsVoteResultHandler);
	DisplayBuiltinVoteToAllNonSpectators(g_hVote, 20);

	FakeClientCommand(client, "Vote Yes");
}

public int VoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			g_hVote = null;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		}
	}
}

public int ForceStartVoteResultHandler(Handle vote, int num_votes, int num_clients, const client_info[][2], int num_items, const item_info[][2])
{
	if (!inReadyUp || inLiveCountdown)
	{
		DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Generic);
		return;
	}
	
	for (int i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_NO) break;
		
		if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] < num_clients)
		{
			DisplayBuiltinVoteFail(vote, BuiltinVoteFail_NotEnoughVotes);
			return;
		}
		
		char buffer[64];
		FormatEx(buffer, sizeof(buffer), "Enforcing to Live...");
		DisplayBuiltinVotePass(vote, buffer);
		CreateTimer(2.0, Timer_ForceStart);
		return;
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action Timer_ForceStart(Handle timer)
{
	InitiateLiveCountdown();
}

public KickSpecsVoteResultHandler(Handle vote, int num_votes, int num_clients, const client_info[][2], int num_items, const item_info[][2])
{
	for (int i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_clients / 2))
			{
				char buffer[64];
				FormatEx(buffer, sizeof(buffer), "Ciao Spectators!");
				DisplayBuiltinVotePass(vote, buffer);
				CreateTimer(2.0, Timer_KickSpecs);
				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action Timer_KickSpecs(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i)) { continue; }
		if (IsPlayer(i)) { continue; }
		if (IsClientCaster(i)) { continue; }
		if (GetUserAdmin(i) != INVALID_ADMIN_ID) { continue; }
					
		KickClient(i, "No Spectators, please!");
	}
}

public Action Ready_Cmd(int client, int args)
{
	if (inReadyUp)
	{
		isPlayerReady[client] = true;
		if (CheckFullReady())
			InitiateLiveCountdown();
	}

	return Plugin_Handled;
}

public Action Unready_Cmd(int client, int args)
{
	if (inReadyUp)
	{
		SetEngineTime(client);
		isPlayerReady[client] = false;
		CancelFullReady();
	}

	return Plugin_Handled;
}

public Action ToggleReady_Cmd(int client, int args)
{
	if (inReadyUp)
	{
		isPlayerReady[client] = !isPlayerReady[client];
		if (isPlayerReady[client] && CheckFullReady())
		{
			InitiateLiveCountdown();
		}
		else
		{
			SetEngineTime(client);
			CancelFullReady();
		}
	}

	return Plugin_Handled;
}

/* No need to do any other checks since it seems like this is required no matter what since the intros unfreezes players after the animation completes */
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (inReadyUp)
	{
		if (buttons || impulse)
		{
			SetEngineTime(client);
		}
		
		/* Mouse Movement Check */
		if (mouse[0] != g_vecLastMouse[client][0]
			|| mouse[1] != g_vecLastMouse[client][1])
		{
			SetEngineTime(client);
			
			g_vecLastMouse[client][0] = mouse[0];
			g_vecLastMouse[client][1] = mouse[1];
		}
		
		if (IsClientInGame(client) && view_as<L4D2_Team>(GetClientTeam(client)) == L4D2Team_Survivor)
		{
			if (l4d_ready_survivor_freeze.BoolValue)
			{
				if (!(GetEntityMoveType(client) == MOVETYPE_NONE || GetEntityMoveType(client) == MOVETYPE_NOCLIP))
				{
					SetClientFrozen(client, true);
				}
			}
			else
			{
				if (GetEntityFlags(client) & FL_INWATER)
				{
					ReturnPlayerToSaferoom(client, false);
				}
			}
			
			if (bSkipWarp)
			{
				SetTeamFrozen(L4D2Team_Survivor, true);
			}

		}
	}
}

public SurvFreezeChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ReturnTeamToSaferoom(L4D2Team_Survivor);
	if (bSkipWarp)
	{
		SetTeamFrozen(L4D2Team_Survivor, true);
	}
	else
	{
		SetTeamFrozen(L4D2Team_Survivor, convar.BoolValue);
	}
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	if (inReadyUp)
	{
		if (bSkipWarp)
		{
			return Plugin_Handled;
		}

		ReturnPlayerToSaferoom(client, false);
		
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Return_Cmd(int client, int args)
{
	if (client > 0
			&& inReadyUp
			&& view_as<L4D2_Team>(GetClientTeam(client)) == L4D2Team_Survivor)
	{
		ReturnPlayerToSaferoom(client, false);
	}
	return Plugin_Handled;
}

public RoundStart_Event(Handle event, const char[] name, bool dontBroadcast)
{
	g_fTime = GetEngineTime();
	InitiateReadyUp();
	
	if (!l4d_ready_enabled.BoolValue)
	{
		CreateTimer(1.0, Timer_InitiateLive, _, TIMER_REPEAT);
	}
}

public PlayerTeam_Event(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	SetEngineTime(client);
	CreateTimer(0.1, Timer_PlayerTeam, client);
}

public Action Timer_PlayerTeam(Handle timer, int client)
{
	if (client > 0 && client <= MaxClients
		&& IsClientInGame(client)
		&& !IsFakeClient(client)
		&& view_as<L4D2_Team>(GetClientTeam(client)) > L4D2Team_Spectator)
	{
		CancelFullReady();
	}
	return Plugin_Handled;
}

#if DEBUG
public Action:InitReady_Cmd(client, args)
{
	InitiateReadyUp();
	return Plugin_Handled;
}

public Action:InitLive_Cmd(client, args)
{
	InitiateLive();
	return Plugin_Handled;
}
#endif

public int DummyHandler(Handle menu, MenuAction action, int param1, int param2) { }

public Action MenuRefresh_Timer(Handle timer)
{
	if (inReadyUp)
	{
		UpdatePanel();
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

public Action MenuCmd_Timer(Handle timer)
{
	if (inReadyUp)
	{
		iCmd += 1;
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

void UpdatePanel()
{
	if (IsBuiltinVoteInProgress()) { return; }
		
	if (menuPanel != null)
	{
		delete menuPanel;
		menuPanel = null;
	}

	char survivorBuffer[800] = "";
	char infectedBuffer[800] = "";
	char casterBuffer[500] = "";
	char specBuffer[800] = "";
	int playerCount = 0;
	int specCount = 0;

	menuPanel = new Panel();

	char ServerBuffer[128];
	char ServerName[32];
	char cfgName[32];
	PrintCmd();

	float fTime = GetEngineTime();
	int iPassTime = RoundToFloor(fTime - g_fTime);

	if (ServerNamer)
	{
		ServerNamer.GetString(ServerName, sizeof(ServerName));
	}
	else
	{
		FindConVar("hostname").GetString(ServerName, sizeof(ServerName));
	}
	l4d_ready_cfg_name.GetString(cfgName, sizeof(cfgName));
	Format(ServerBuffer, sizeof(ServerBuffer), "▸ Server: %s \n▸ Slots: %d/%d\n▸ Config: %s", ServerName, GetSeriousClientCount(), FindConVar("sv_maxplayers").IntValue, cfgName);
	menuPanel.DrawText(ServerBuffer);
	
	FormatTime(ServerBuffer, sizeof(ServerBuffer), "▸ %m/%d/%Y - %I:%M%p");
	Format(ServerBuffer, sizeof(ServerBuffer), "%s (%s%d:%s%d)", ServerBuffer, (iPassTime / 60 < 10) ? "0" : "", iPassTime / 60, (iPassTime % 60 < 10) ? "0" : "", iPassTime % 60);
	menuPanel.DrawText(ServerBuffer);
	
	menuPanel.DrawText(" ");
	menuPanel.DrawText("▸ Commands:");
	menuPanel.DrawText(sCmd);
	menuPanel.DrawText(" ");
	
	char nameBuf[64];
	char authBuffer[64];
	bool caster;
	any dummy;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			++playerCount;
			GetClientName(client, nameBuf, sizeof(nameBuf));
			GetClientAuthId(client, AuthId_Steam2, authBuffer, sizeof(authBuffer));
			caster = casterTrie.GetValue(authBuffer, dummy);
			
			if (IsPlayer(client))
			{
				if (isPlayerReady[client])
				{
					if (!inLiveCountdown) PrintHintText(client, "You are ready.\nSay !unready / Press F2 to unready.");
					switch (view_as<L4D2_Team>(GetClientTeam(client)))
					{
						case L4D2Team_Survivor: {
							Format(nameBuf, sizeof(nameBuf), "☑ %s\n", nameBuf);
							StrCat(survivorBuffer, sizeof(survivorBuffer), nameBuf);
						}
						case L4D2Team_Infected: {
							Format(nameBuf, sizeof(nameBuf), "☑ %s\n", nameBuf);
							StrCat(infectedBuffer, sizeof(infectedBuffer), nameBuf);
						}
					}
				}
				else 
				{
					if (view_as<L4D2_Team>(GetClientTeam(client)) != L4D2Team_Spectator)
						if (!inLiveCountdown)
							PrintHintText(client, "You are not ready.\nSay !ready / Press F1 to ready up.");
							
					switch (view_as<L4D2_Team>(GetClientTeam(client)))
					{
						case L4D2Team_Survivor: {
							Format(nameBuf, sizeof(nameBuf), "☐ %s%s\n", nameBuf, ( IsPlayerAfk(client, fTime) ? " [AFK]" : "" ));
							StrCat(survivorBuffer, sizeof(survivorBuffer), nameBuf);
						}
						case L4D2Team_Infected: {
							Format(nameBuf, sizeof(nameBuf), "☐ %s%s\n", nameBuf, ( IsPlayerAfk(client, fTime) ? " [AFK]" : "" ));
							StrCat(infectedBuffer, sizeof(infectedBuffer), nameBuf);
						}
					}
				}
			}
			else
			{
				++specCount;
				if (caster)
				{
					Format(nameBuf, sizeof(nameBuf), "%s\n", nameBuf);
					StrCat(casterBuffer, sizeof(casterBuffer), nameBuf);
				}
				else
				{
					if (playerCount <= l4d_ready_max_players.IntValue)
					{
						Format(nameBuf, sizeof(nameBuf), "%s\n", nameBuf);
						StrCat(specBuffer, sizeof(specBuffer), nameBuf);
					}
				}
			}
		}
	}
	
	int textCount = 0;
	int bufLen = strlen(survivorBuffer);
	if (bufLen != 0)
	{
		survivorBuffer[bufLen] = '\0';
		ReplaceString(survivorBuffer, sizeof(survivorBuffer), "#buy", "<- TROLL");
		ReplaceString(survivorBuffer, sizeof(survivorBuffer), "#", "_");
		Format(nameBuf, sizeof(nameBuf), "->%d. Survivors", ++textCount);
		menuPanel.DrawText(nameBuf);
		menuPanel.DrawText(survivorBuffer);
	}

	bufLen = strlen(infectedBuffer);
	if (bufLen != 0)
	{
		infectedBuffer[bufLen] = '\0';
		ReplaceString(infectedBuffer, sizeof(infectedBuffer), "#buy", "<- TROLL");
		ReplaceString(infectedBuffer, sizeof(infectedBuffer), "#", "_");
		Format(nameBuf, sizeof(nameBuf), "->%d. Infected", ++textCount);
		menuPanel.DrawText(nameBuf);
		menuPanel.DrawText(infectedBuffer);
	}

	bufLen = strlen(casterBuffer);
	if (bufLen != 0)
	{
		casterBuffer[bufLen] = '\0';
		Format(nameBuf, sizeof(nameBuf), "->%d. Casters", ++textCount);
		menuPanel.DrawText(nameBuf);
		ReplaceString(casterBuffer, sizeof(casterBuffer), "#", "_", true);
		menuPanel.DrawText(casterBuffer);
	}
	
	bufLen = strlen(specBuffer);
	if (bufLen != 0)
	{
		specBuffer[bufLen] = '\0';
		Format(nameBuf, sizeof(nameBuf), "->%d. Spectators", ++textCount);
		menuPanel.DrawText(nameBuf);
		ReplaceString(specBuffer, sizeof(specBuffer), "#", "_");
		if (playerCount > GetConVarInt(l4d_ready_max_players))
			FormatEx(specBuffer, sizeof(specBuffer), "**Many** (%d)", specCount);
		menuPanel.DrawText(specBuffer);
	}

	bufLen = strlen(readyFooter[0]);
	if (bufLen != 0)
	{
		for (int i = 0; i < MAX_FOOTERS; i++)
		{
			menuPanel.DrawText(readyFooter[i]);
		}
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && !hiddenPanel[client])
		{
			menuPanel.Send(client, DummyHandler, 1);
		}
	}
}

void InitiateReadyUp()
{
	for (int i = 0; i <= MAXPLAYERS; i++)
	{
		isPlayerReady[i] = false;
	}

	UpdatePanel();
	CreateTimer(1.0, MenuRefresh_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(4.0, MenuCmd_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	inReadyUp = true;
	inLiveCountdown = false;
	readyCountdownTimer = INVALID_HANDLE;

	if (l4d_ready_disable_spawns.BoolValue)
	{
		director_no_specials.SetBool(true);
	}

	DisableEntities();
	SetConVarFlags(sv_infinite_primary_ammo, god.Flags & ~FCVAR_NOTIFY);
	sv_infinite_primary_ammo.SetBool(true);
	SetConVarFlags(sv_infinite_primary_ammo, god.Flags | FCVAR_NOTIFY);
	SetConVarFlags(god, god.Flags & ~FCVAR_NOTIFY);
	god.SetBool(true);
	SetConVarFlags(god, god.Flags | FCVAR_NOTIFY);
	sb_stop.SetBool(true);

	L4D2_CTimerStart(L4D2CT_VersusStartTimer, 99999.9);
}

void PrintCmd()
{
	if (iCmd > 9)
	{
		iCmd = 1;
	}
	switch (iCmd)
	{
		case 1: {
			Format(sCmd, sizeof(sCmd), "->1. !ready|!r / !unready|!nr");
		}
		case 2: {
			Format(sCmd, sizeof(sCmd), "->2. !slots #");
		}
		case 3: {
			Format(sCmd, sizeof(sCmd), "->3. !voteboss <tank> <witch>");
		}
		case 4: {
			Format(sCmd, sizeof(sCmd), "->4. !match / !rmatch");
		}
		case 5: {
			Format(sCmd, sizeof(sCmd), "->5. !show / !hide");
		}
		case 6: {
			Format(sCmd, sizeof(sCmd), "->6. !setscores <survs> <inf>");
		}
		case 7: {
			Format(sCmd, sizeof(sCmd), "->7. !lerps");
		}
		case 8: {
			Format(sCmd, sizeof(sCmd), "->8. !secondary");
		}
		case 9: {
			Format(sCmd, sizeof(sCmd), "->9. !forcestart / !fs");
		}
		default: {
		}
	}
}

void InitiateLive(bool real = true)
{
	inReadyUp = false;
	inLiveCountdown = false;

	SetTeamFrozen(L4D2Team_Survivor, false);

	EnableEntities();
	SetConVarFlags(sv_infinite_primary_ammo, god.Flags & ~FCVAR_NOTIFY);
	sv_infinite_primary_ammo.SetBool(false);
	SetConVarFlags(sv_infinite_primary_ammo, god.Flags | FCVAR_NOTIFY);
	director_no_specials.SetBool(false);
	SetConVarFlags(god, god.Flags & ~FCVAR_NOTIFY);
	god.SetBool(false);
	SetConVarFlags(god, god.Flags | FCVAR_NOTIFY);
	sb_stop.SetBool(false);
	
	L4D2_CTimerStart(L4D2CT_VersusStartTimer, 60.0);

	for (int i = 0; i < 4; i++)
	{
		GameRules_SetProp("m_iVersusDistancePerSurvivor", 0, _,
				i + 4 * GameRules_GetProp("m_bAreTeamsFlipped"));
	}

	for (int i = 0; i < MAX_FOOTERS; i++)
	{
		readyFooter[i] = "";
	}
	footerCounter = 0;

	if (real)
	{
		Call_StartForward(liveForward);
		Call_Finish();
	}
}

void ReturnPlayerToSaferoom(int client, bool flagsSet = true)
{
	int warp_flags;
	int give_flags;
	if (!flagsSet)
	{
		warp_flags = GetCommandFlags("warp_to_start_area");
		SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
		give_flags = GetCommandFlags("give");
		SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);
	}

	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
	{
		FakeClientCommand(client, "give health");
	}

	FakeClientCommand(client, "warp_to_start_area");

	if (!flagsSet)
	{
		SetCommandFlags("warp_to_start_area", warp_flags);
		SetCommandFlags("give", give_flags);
	}
}

void ReturnTeamToSaferoom(L4D2_Team team)
{
	int warp_flags = GetCommandFlags("warp_to_start_area");
	SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
	int give_flags = GetCommandFlags("give");
	SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && view_as<L4D2_Team>(GetClientTeam(client)) == team)
		{
			ReturnPlayerToSaferoom(client, true);
		}
	}

	SetCommandFlags("warp_to_start_area", warp_flags);
	SetCommandFlags("give", give_flags);
}



void SetTeamFrozen(L4D2_Team team, bool freezeStatus)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && view_as<L4D2_Team>(GetClientTeam(client)) == team)
		{
			SetClientFrozen(client, freezeStatus);
		}
	}
}

bool CheckFullReady()
{
	int readyCount = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			if (IsPlayer(client) && isPlayerReady[client])
			{
				readyCount++;
			}
		}
	}
	
	return readyCount >= GetConVarInt(survivor_limit); //+ GetConVarInt(z_max_player_zombies);
}

void InitiateLiveCountdown()
{
	if (readyCountdownTimer == null)
	{
		ReturnTeamToSaferoom(L4D2Team_Survivor);
		SetTeamFrozen(L4D2Team_Survivor, true);
		PrintHintTextToAll("Going live!\nSay !unready / Press F2 to cancel");
		inLiveCountdown = true;
		readyDelay = l4d_ready_delay.IntValue;
		readyCountdownTimer = CreateTimer(1.0, ReadyCountdownDelay_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action ReadyCountdownDelay_Timer(Handle timer)
{
	if (readyDelay == 0)
	{
		PrintHintTextToAll("Round is live!");
		InitiateLive();
		readyCountdownTimer = null;
		if (l4d_ready_enable_sound.BoolValue)
		{
			if (l4d_ready_chuckle.BoolValue)
			{
				EmitSoundToAll(chuckleSound[GetRandomInt(0,MAX_SOUNDS-1)]);
			}
			else { EmitSoundToAll(liveSound, _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5); }
		}
		return Plugin_Stop;
	}
	else
	{
		PrintHintTextToAll("Live in: %d\nSay !unready / Press F2 to cancel", readyDelay);
		if (l4d_ready_enable_sound.BoolValue)
		{
			EmitSoundToAll(countdownSound, _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		}
		readyDelay--;
	}
	return Plugin_Continue;
}

void CancelFullReady()
{
	if (readyCountdownTimer != INVALID_HANDLE)
	{
		if (bSkipWarp)
		{
			SetTeamFrozen(L4D2Team_Survivor, true);
		}
		else
		{
			SetTeamFrozen(L4D2Team_Survivor, GetConVarBool(l4d_ready_survivor_freeze));
		}
		inLiveCountdown = false;
		KillTimer(readyCountdownTimer);
		readyCountdownTimer = null;
		PrintHintTextToAll("Countdown Cancelled!");
	}
}

stock int GetSeriousClientCount()
{
	int clients = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
		{
			clients++;
		}
	}
	
	return clients;
}

stock int SetClientFrozen(int client, bool freeze)
{
	SetEntityMoveType(client, freeze ? MOVETYPE_NONE : MOVETYPE_WALK);
}

stock bool IsPlayerAfk(int client, float fTime)
{
	return fTime - g_fButtonTime[client] > 15.0;
}

stock bool IsPlayer(int client)
{
	L4D2_Team team = view_as<L4D2_Team>(GetClientTeam(client));
	return (team == L4D2Team_Survivor || team == L4D2Team_Infected);
}

stock int GetTeamHumanCount(L4D2_Team team)
{
	int humans = 0;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && view_as<L4D2_Team>(GetClientTeam(client)) == team)
		{
			humans++;
		}
	}
	
	return humans;
}

void DisableEntities()
{
	ActivateEntities("prop_door_rotating", "SetUnbreakable");
	MakePropsUnbreakable();
}

void EnableEntities()
{
	ActivateEntities("prop_door_rotating", "SetBreakable");
	MakePropsBreakable();
}


ActivateEntities(char[] className, char[] inputName)
{ 
	int iEntity;

	while ((iEntity = FindEntityByClassname(iEntity, className)) != -1)
	{
		if (!IsValidEdict(iEntity) || !IsValidEntity(iEntity)) {
			continue;
		}
		
		AcceptEntityInput(iEntity, inputName);
	}
}

MakePropsUnbreakable()
{
	int iEntity;
	
	while ((iEntity = FindEntityByClassname(iEntity, "prop_physics")) != -1)
	{
		if (!IsValidEdict(iEntity) || !IsValidEntity(iEntity)) {
			continue;
		}
		DispatchKeyValueFloat(iEntity, "minhealthdmg", 10000.0);
	}
}

MakePropsBreakable()
{
	int iEntity;
    
	while ((iEntity = FindEntityByClassname(iEntity, "prop_physics")) != -1)
	{
		if (!IsValidEdict(iEntity) ||  !IsValidEntity(iEntity)) {
			continue;
		}
		DispatchKeyValueFloat(iEntity, "minhealthdmg", 5.0);
	}
}