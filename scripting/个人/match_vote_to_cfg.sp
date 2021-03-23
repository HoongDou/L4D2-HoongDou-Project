
#include <sourcemod>
#include <builtinvotes>
//get here: https://forums.alliedmods.net/showthread.php?t=162164

#undef REQUIRE_PLUGIN
#include <confogl>
#include <colors>
#define REQUIRE_PLUGIN
//get proper version here: https://bitbucket.org/vintik/confogl-old

#define L4D_TEAM_SPECTATE	1
#define FILE_PATH		"configs/cfgs.txt"

new Handle:g_hVote;
new Handle:g_hVotesKV;
new Handle:g_hCvarPlayerLimit;
new Handle:g_hMaxPlayers;
new Handle:g_hSvMaxPlayers;
new String:g_sCfg[32];
new bool:g_bIsConfoglAvailable;
new bool:OnSet

public Plugin:myinfo = 
{
	name = "Match Vote",
	author = "vintik, Sir",
	description = "!match !rmatch - Change Hostname and Slots while you're at it!",
	version = "1.1.3",
	url = "https://bitbucket.org/vintik/various-plugins"
}

public OnPluginStart()
{
	decl String:sBuffer[128];
	GetGameFolderName(sBuffer, sizeof(sBuffer));
	if (!StrEqual(sBuffer, "left4dead2", false))
	{
		SetFailState("Plugin supports Left 4 dead 2 only!");
	}
	g_hVotesKV = CreateKeyValues("Votes");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), FILE_PATH);
	if (!FileToKeyValues(g_hVotesKV, sBuffer))
	{
		SetFailState("Couldn't load cfgs.txt!");
	}
	
	g_hSvMaxPlayers = FindConVar("sv_maxplayers");
	g_hMaxPlayers = CreateConVar("mv_maxplayers", "30", "How many slots would you like the Server to be at Config Load/Unload?");
	RegConsoleCmd("sm_votes", MatchRequest);
	
	g_hCvarPlayerLimit = CreateConVar("sm_match_player_limit", "1", "Minimum # of players in game to start the vote");
	g_bIsConfoglAvailable = LibraryExists("confogl");
}

public OnConfigsExecuted()
{
	if (!OnSet)
	{
		SetConVarInt(g_hSvMaxPlayers, GetConVarInt(g_hMaxPlayers));
		OnSet = true;
	}
}

public OnPluginEnd()
{
	SetConVarInt(g_hSvMaxPlayers, GetConVarInt(g_hMaxPlayers));
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "confogl")) g_bIsConfoglAvailable = false;
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "confogl")) g_bIsConfoglAvailable = true;
}

public Action:MatchRequest(client, args)
{
	if ((!client) || (!g_bIsConfoglAvailable)) return Plugin_Handled;
	if (args > 0)
	{
		//config specified
		new String:sCfg[64], String:sName[64];
		GetCmdArg(1, sCfg, sizeof(sCfg));
		if (FindConfigName(sCfg, sName, sizeof(sName)))
		{
			if (StartMatchVote(client, sName))
			{
				strcopy(g_sCfg, sizeof(g_sCfg), sCfg);
				//caller is voting for
				FakeClientCommand(client, "Vote Yes");
			}
			return Plugin_Handled;
		}
	}
	//show main menu
	MatchModeMenu(client);
	return Plugin_Handled;
}

bool:FindConfigName(const String:cfg[], String:name[], maxlength)
{
	KvRewind(g_hVotesKV);
	if (KvGotoFirstSubKey(g_hVotesKV))
	{
		do
		{
			if (KvJumpToKey(g_hVotesKV, cfg))
			{
				KvGetString(g_hVotesKV, "name", name, maxlength);
				return true;
			}
		} while (KvGotoNextKey(g_hVotesKV, false));
	}
	return false;
}

MatchModeMenu(client)
{
	new Handle:hMenu = CreateMenu(MatchModeMenuHandler);
	SetMenuTitle(hMenu, "Select The Vote");
	new String:sBuffer[64];
	KvRewind(g_hVotesKV);
	if (KvGotoFirstSubKey(g_hVotesKV))
	{
		do
		{
			KvGetSectionName(g_hVotesKV, sBuffer, sizeof(sBuffer));
			AddMenuItem(hMenu, sBuffer, sBuffer);
		} while (KvGotoNextKey(g_hVotesKV, false));
	}
	DisplayMenu(hMenu, client, 20);
}

public MatchModeMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:sInfo[64], String:sBuffer[64];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		KvRewind(g_hVotesKV);
		if (KvJumpToKey(g_hVotesKV, sInfo) && KvGotoFirstSubKey(g_hVotesKV))
		{
			new Handle:hMenu = CreateMenu(ConfigsMenuHandler);
			Format(sBuffer, sizeof(sBuffer), "Select %s config:", sInfo);
			SetMenuTitle(hMenu, sBuffer);
			do
			{
				KvGetSectionName(g_hVotesKV, sInfo, sizeof(sInfo));
				KvGetString(g_hVotesKV, "name", sBuffer, sizeof(sBuffer));
				AddMenuItem(hMenu, sInfo, sBuffer);
			} while (KvGotoNextKey(g_hVotesKV));
			DisplayMenu(hMenu, param1, 20);
		}
		else
		{
			CPrintToChat(param1, "{blue}[{default}Match{blue}] {default}No configs for such vote were found.");
			MatchModeMenu(param1);
		}
	}
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public ConfigsMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:sInfo[64], String:sBuffer[64];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo), _, sBuffer, sizeof(sBuffer));
		if (StartMatchVote(param1, sBuffer))
		{
			strcopy(g_sCfg, sizeof(g_sCfg), sInfo);
			//caller is voting for
			FakeClientCommand(param1, "Vote Yes");
		}
		else
		{
			MatchModeMenu(param1);
		}
	}
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	if (action == MenuAction_Cancel)
	{
		MatchModeMenu(param1);
	}
}

bool:StartMatchVote(client, const String:cfgname[])
{
	if (!IsBuiltinVoteInProgress())
	{
		new iNumPlayers;
		decl iPlayers[MaxClients];
		//list of non-spectators players
		for (new i=1; i<=MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) == L4D_TEAM_SPECTATE)) || (GetUserAdmin(client) == INVALID_ADMIN_ID))
			{
				continue;
			}
			iPlayers[iNumPlayers++] = i;
		}
		if (iNumPlayers < GetConVarInt(g_hCvarPlayerLimit))
		{
			CPrintToChat(client, "{blue}[{default}Vote{blue}] {default}vote cannot be started. Not enough players.");
			return false;
		}
		new String:sBuffer[64];
		g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		Format(sBuffer, sizeof(sBuffer), "Load confogl '%s' config?", cfgname);
		SetBuiltinVoteArgument(g_hVote, sBuffer);
		SetBuiltinVoteInitiator(g_hVote, client);
		SetBuiltinVoteResultCallback(g_hVote, MatchVoteResultHandler);
		DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, 20);
		return true;
	}
	CPrintToChat(client, "{blue}[{default}Vote{blue}] {default} vote cannot be started now.");
	return false;
}

public VoteActionHandler(Handle:vote, BuiltinVoteAction:action, param1, param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			g_hVote = INVALID_HANDLE;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, BuiltinVoteFailReason:param1);
		}
	}
}

public MatchVoteResultHandler(Handle:vote, num_votes, num_clients, const client_info[][2], num_items, const item_info[][2])
{
	for (new i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				DisplayBuiltinVotePass(vote, "Vote Passed");
				ServerCommand("%s", g_sCfg);
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}


ConnectingPlayers()
{
	new Clients = 0;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) && IsClientConnected(i))
			
		Clients++;
	}
	return Clients;
}