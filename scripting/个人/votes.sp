
#include <sourcemod>
#include <builtinvotes>
#undef REQUIRE_PLUGIN
#include <confogl>
#include <colors>
#define REQUIRE_PLUGIN

#define L4D_TEAM_SPECTATE	1					   
#define FILE_PATH		"configs/cfgs.txt"

new Handle:g_hVote;
new Handle:g_hVoteKick;
new Handle:g_hCvarPlayerLimit;
new Handle:g_hCfgsKV;
new Handle:g_hMaxPlayers;
new Handle:g_hSvMaxPlayers;
new String:g_sCfg[32];
new bool:g_bIsConfoglAvailable;
new bool:OnSet
new String:kickplayerinfo[MAX_NAME_LENGTH];
new String:kickplayername[MAX_NAME_LENGTH];

public Plugin:myinfo = 
{
	name = "投票读取cfg文件",
	author = "vintik, Sir,HazukiYuro,HoongDou",
	description = "!vote投票",
	version = "1.1.4",
	url = ""
}

public OnPluginStart()
{
	decl String:sBuffer[128];
	GetGameFolderName(sBuffer, sizeof(sBuffer));
	if (!StrEqual(sBuffer, "left4dead2", false))
	{
		SetFailState("Plugin supports Left 4 dead 2 only!");
	}
	g_hCfgsKV = CreateKeyValues("Cfgs");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), FILE_PATH);
	if (!FileToKeyValues(g_hCfgsKV, sBuffer))
	{
		SetFailState("Couldn't load cfgs.txt!");
	}
 	g_hSvMaxPlayers = FindConVar("sv_maxplayers");
	g_hMaxPlayers = CreateConVar("mv_maxplayers", "30", "How many slots would you like the Server to be at Config Load/Unload?");
	RegConsoleCmd("sm_votes", CommondVote);
	RegConsoleCmd("sm_vote", CommondVote);
	RegConsoleCmd("sm_mode", CommondVote);
	RegConsoleCmd("sm_votekick", Command_Voteskick);
	RegConsoleCmd("sm_serverhp", Command_ServerHp, _, ADMFLAG_KICK);
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

stock CheatCommand(Client, const String:command[], const String:arguments[])
{
	new admindata = GetUserFlagBits(Client);
	SetUserFlagBits(Client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(Client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(Client, admindata);
}

public Action:Command_ServerHp(client, args)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			CheatCommand(i, "give", "health");
		}
	}
	CPrintToChatAll("{blue}[{default}Vote{blue}] {default}Vote passed to give health");
	ReplyToCommand(client, "done");
	return Plugin_Handled;
}

public Action:CommondVote(client, args)
{
	if ((!client) || (!g_bIsConfoglAvailable))  return Plugin_Handled;
	if (args > 0)
	{
		decl String:sCfg[64], String:sBuffer[256];
		GetCmdArg(1, sCfg, sizeof(sCfg));
		BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "../../cfg/%s", sCfg);
		if (DirExists(sBuffer))
		{
			FindConfigName(sCfg, sBuffer, sizeof(sBuffer));
			if (StartVote(client, sBuffer))
			{
				strcopy(g_sCfg, sizeof(g_sCfg), sCfg);
				FakeClientCommand(client, "Vote Yes");
			}
			return Plugin_Handled;
		}
	}
	ShowVoteMenu(client);
	return Plugin_Handled;
}

bool:FindConfigName(const String:cfg[], String:message[], maxlength)
{
	KvRewind(g_hCfgsKV);
	if (KvGotoFirstSubKey(g_hCfgsKV))
	{
		do
		{
			if (KvJumpToKey(g_hCfgsKV, cfg))
			{
				KvGetString(g_hCfgsKV, "name", message, maxlength);
				return true;
			}
		} while (KvGotoNextKey(g_hCfgsKV,false));
	}
	return false;
}

ShowVoteMenu(client)
{
	new Handle:hMenu = CreateMenu(VoteMenuHandler);
	SetMenuTitle(hMenu, "Select The Vote:");
	new String:sBuffer[64];
	KvRewind(g_hCfgsKV);
	if (KvGotoFirstSubKey(g_hCfgsKV))
	{
		do
		{
			KvGetSectionName(g_hCfgsKV, sBuffer, sizeof(sBuffer));
			AddMenuItem(hMenu, sBuffer, sBuffer);
		} while (KvGotoNextKey(g_hCfgsKV,false));
	}
	DisplayMenu(hMenu, client, 20);
}

public VoteMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:sInfo[64], String:sBuffer[64];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		KvRewind(g_hCfgsKV);
		if (KvJumpToKey(g_hCfgsKV, sInfo) && KvGotoFirstSubKey(g_hCfgsKV))
		{
			new Handle:hMenu = CreateMenu(ConfigsMenuHandler);
			Format(sBuffer, sizeof(sBuffer), "Select %s Config:", sInfo);
			SetMenuTitle(hMenu, sBuffer);
			do
			{
				KvGetSectionName(g_hCfgsKV, sInfo, sizeof(sInfo));
				KvGetString(g_hCfgsKV, "name", sBuffer, sizeof(sBuffer));
				AddMenuItem(hMenu, sInfo, sBuffer);
			} while (KvGotoNextKey(g_hCfgsKV));
			DisplayMenu(hMenu, param1, 20);
		}
		else
		{
			CPrintToChat(param1, "{blue}[{default}Vote{blue}] {default}No configs for such vote were found.");
			ShowVoteMenu(param1);
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
		strcopy(g_sCfg, sizeof(g_sCfg), sInfo);
		
		if(!StrEqual(g_sCfg, "sm_votekick"))
		{
			if (StartVote(param1, sBuffer))
			{
				FakeClientCommand(param1, "Vote Yes");
			}
			else
			{
				ShowVoteMenu(param1);
			}
		}
		else
		{
			FakeClientCommand(param1, "sm_votekick");
		}
	}
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	if (action == MenuAction_Cancel)
	{
		ShowVoteMenu(param1);
	}
}

bool:StartVote(client, const String:cfgname[])
{
	if (ConnectingPlayers() > 0)
	{
		CPrintToChat(client, "{blue}[{default}Vote{blue}] {default}Vote cannot be started. Players are connecting");
		return false;
	}
	if (!IsBuiltinVoteInProgress())
	{
		new iNumPlayers;
		decl iPlayers[MaxClients];
		//list of non-spectators players
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) == L4D_TEAM_SPECTATE))
			{
				continue;
			}
			iPlayers[iNumPlayers++] = i;
		}
		if (iNumPlayers < GetConVarInt(g_hCvarPlayerLimit))
		{
		//check admins
			if((GetUserAdmin(client) == INVALID_ADMIN_ID))
			{
				CPrintToChat(client, "{blue}[{default}Vote{blue}] {default}Vote cannot be started. Not enough players.");
				return false;
			}
		}
		new String:sBuffer[64];
		g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		Format(sBuffer, sizeof(sBuffer), "Load confogl '%s' config?", cfgname);
		SetBuiltinVoteArgument(g_hVote, sBuffer);
		SetBuiltinVoteInitiator(g_hVote, client);
		SetBuiltinVoteResultCallback(g_hVote, VoteResultHandler);
		DisplayBuiltinVoteToAll(g_hVote, 20);
		//PrintToChatAll("\x04%N \x03发起了一个投票", client);
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

public VoteResultHandler(Handle:vote, num_votes, num_clients, const client_info[][2], num_items, const item_info[][2])
{
	for (new i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] >= (num_clients * 0.6))
			{
				if (vote == g_hVote)
				{
					DisplayBuiltinVotePass(vote, "Loading Cfg...");
					ServerCommand("%s", g_sCfg);
					return;
				}
				else if(vote == g_hVoteKick)
				{
					ServerCommand("sm_kick %s are Kickd by Vote", kickplayername);
					return;
				}
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action:Command_Voteskick(client, args)
{
	if(client != 0 && client <= MaxClients) 
	{
		CreateVotekickMenu(client);
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

CreateVotekickMenu(client)
{
	new Handle:menu = CreateMenu(Menu_Voteskick);		
	new String:name[MAX_NAME_LENGTH];
	new String:info[MAX_NAME_LENGTH + 6];
	new String:playerid[32];
	SetMenuTitle(menu, "Choose which Players to kick");
	for(new i = 1;i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			Format(playerid,sizeof(playerid),"%i",GetClientUserId(i));
			if(GetClientName(i,name,sizeof(name)))
			{
				Format(info, sizeof(info), "%s",  name);
				AddMenuItem(menu, playerid, info);
			}
		}		
	}
	DisplayMenu(menu, client, 30);
}
public Menu_Voteskick(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)

	{
		new String:info[32] , String:name[32];
		GetMenuItem(menu, param2, info, sizeof(info), _, name, sizeof(name));
		kickplayerinfo = info;
		kickplayername = name;
		//PrintToChatAll("\x04%N Start a vote to kick \x05 %s", param1, kickplayername);
		if(DisplayVoteKickMenu(param1)) FakeClientCommand(param1, "Vote Yes");
		
	}
}

public bool:DisplayVoteKickMenu(client)
{
	if (!IsBuiltinVoteInProgress())
	{
		new iNumPlayers;
		decl iPlayers[MaxClients];
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
			{
				continue;
			}
			iPlayers[iNumPlayers++] = i;
		}
		new String:sBuffer[64];
		g_hVoteKick = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		Format(sBuffer, sizeof(sBuffer), "Kick '%s' ?", kickplayername);
		SetBuiltinVoteArgument(g_hVoteKick, sBuffer);
		SetBuiltinVoteInitiator(g_hVoteKick, client);
		SetBuiltinVoteResultCallback(g_hVoteKick, VoteResultHandler);
		DisplayBuiltinVoteToAll(g_hVoteKick, 20);
		//PrintToChatAll("\x04%N \x03发起了一个投票", client);
		return true;
	}
	CPrintToChat(client, "{blue}[{default}Vote{blue}] {default} vote cannot be started now.");
	return false;
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