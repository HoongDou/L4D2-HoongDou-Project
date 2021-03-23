#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <adminmenu>
#undef REQUIRE_PLUGIN
#define PLUGIN_VERSION "1.9.3"
#define CVAR_FLAGS FCVAR_SPONLY|FCVAR_NOTIFY
new Handle:hAdminMenu = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "L4D SM Respawn",
	author = "AtomicStryker & Ivailosp",
	description = "Let's you respawn Players by console",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=96249"
}

static Float:g_pos[3];
static Handle:hRoundRespawn = INVALID_HANDLE;
static Handle:hBecomeGhost = INVALID_HANDLE;
static Handle:hState_Transition = INVALID_HANDLE;
static Handle:hGameConf = INVALID_HANDLE;

public OnPluginStart()
{
	decl String:game_name[24];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead2", false) && !StrEqual(game_name, "left4dead", false))
	{
		SetFailState("Plugin supports Left 4 Dead and L4D2 only.");
	}

	LoadTranslations("common.phrases");
	hGameConf = LoadGameConfigFile("l4drespawn");
	
	CreateConVar("l4d_sm_respawn_version", PLUGIN_VERSION, "L4D SM Respawn Version", CVAR_FLAGS|FCVAR_SPONLY|FCVAR_NOTIFY);
	RegAdminCmd("sm_respawn", Command_Respawn, 0, "sm_respawn <player1> [player2] ... [playerN] - respawn all listed players and teleport them where you aim");
	RegAdminCmd("fuhuo", Command_FuHuo, 0, "复活菜单");
	if (hGameConf != INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "RoundRespawn");
		hRoundRespawn = EndPrepSDKCall();
		if (hRoundRespawn == INVALID_HANDLE) SetFailState("L4D_SM_Respawn: RoundRespawn Signature broken");
		
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "BecomeGhost");
		PrepSDKCall_AddParameter(SDKType_PlainOldData , SDKPass_Plain);
		hBecomeGhost = EndPrepSDKCall();
		if (hBecomeGhost == INVALID_HANDLE && StrEqual(game_name, "left4dead2", false))
			LogError("L4D_SM_Respawn: BecomeGhost Signature broken");

		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "State_Transition");
		PrepSDKCall_AddParameter(SDKType_PlainOldData , SDKPass_Plain);
		hState_Transition = EndPrepSDKCall();
		if (hState_Transition == INVALID_HANDLE && StrEqual(game_name, "left4dead2", false))
			LogError("L4D_SM_Respawn: State_Transition Signature broken");
	}
	else
	{
		SetFailState("could not find gamedata file at addons/sourcemod/gamedata/l4drespawn.txt , you FAILED AT INSTALLING");
	}
}

public Action:Command_FuHuo(int client, int args)
{
	DisplayPlayerMenu(client);
	return Plugin_Handled;
}

public OnLibraryRemoved(const String:name[])
{
    if (StrEqual(name, "adminmenu")) 
	{
        hAdminMenu = INVALID_HANDLE;
    }
}

public OnAdminMenuReady(Handle:topmenu)
{
	if (hAdminMenu == topmenu) 
	{
		return;
	}
	hAdminMenu = topmenu;
	new TopMenuObject:player_commands = FindTopMenuCategory(hAdminMenu, "PlayerCommands");
	if (player_commands) 
	{
		AddToTopMenu(hAdminMenu, "sm_respawn", TopMenuObject_Item, AdminMenu_respawn, player_commands, "sm_respawn", ADMFLAG_SLAY);
	}
}

public AdminMenu_respawn(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action) 
	{
		if (action == TopMenuAction_SelectOption) 
		{
			DisplayPlayerMenu(param);
		}
	} 
	else 
	{
		Format(buffer, maxlength, "复活玩家");
	}
}

DisplayPlayerMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_Players);
	decl String:title[100];
	Format(title, 100, "选择玩家:");
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	AddTargetsToMenu(menu, client, true, false);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Players(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End) 
	{
		CloseHandle(menu);
	} 
	else 
	{
		if (action == MenuAction_Cancel) 
		{
			if (param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE) 
			{
				DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
			}
		}
		if (action == MenuAction_Select) 
		{
			decl String:info[32];
			new userid, target;
			GetMenuItem(menu, param2, info, sizeof(info));
			userid = StringToInt(info);
			new Client = GetClientOfUserId(userid);
			target = Client;
			if (Client) 
			{
				if (!CanUserTarget(param1, target)) 
				{
					PrintToChat(param1, "[SM] %s", "没有目标");
				}
				decl String:pname[32];
				GetClientName(target, pname, sizeof(info));
				FakeClientCommand(param1, "sm_respawn %s", pname);
			} 
			else 
			{
				PrintToChat(param1, "[SM] %s", "Player no longer available");
			}
			if (IsClientInGame(param1)) 
			{
				DisplayPlayerMenu(param1);
			}
		}
	}
}

public Action:Command_Respawn(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_respawn <player1> [player2] ... [playerN] - respawn all listed players");
		return Plugin_Handled;
	}
	
	decl String:arg1[MAX_TARGET_LENGTH];
	decl String:target_name[MAX_TARGET_LENGTH];
	new target_list[MAXPLAYERS];
	new target_count;
	new bool:tn_is_ml;
	
	GetCmdArg(1, arg1, sizeof(arg1));
 
	if ((target_count = ProcessTargetString(arg1,client,target_list,MAXPLAYERS,0,target_name,sizeof(target_name),tn_is_ml)) <= 0)
	{
		/* This function replies to the admin with a failure message */
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (new i = 0; i < target_count; i++)
	{
		RespawnPlayer(client, target_list[i]);
	}
	
	ShowActivity2(client, "\x04管理员复活了 \x03%s", target_name);
	
	return Plugin_Handled;
}

static RespawnPlayer(client, player_id)
{
	switch(GetClientTeam(player_id))
	{
		case 0:
		{
			new bool:canTeleport = SetTeleportEndPoint(client);
		
			SDKCall(hRoundRespawn, player_id);
			
			CheatCommand(player_id, "give", "first_aid_kit");
			CheatCommand(player_id, "give", "smg");
			
			if(canTeleport)
			{
				PerformTeleport(client,player_id,g_pos);
			}
		}	
		case 1:
		{
			decl String:game_name[24];
			GetGameFolderName(game_name, sizeof(game_name));
			if (StrEqual(game_name, "left4dead", false)) return;
		
			SDKCall(hState_Transition, player_id, 8);
			SDKCall(hBecomeGhost, player_id, 1);
			SDKCall(hState_Transition, player_id, 6);
			SDKCall(hBecomeGhost, player_id, 1);
		}
	}
}

public bool:TraceEntityFilterPlayer(entity, contentsMask)
{
	return entity > MaxClients || !entity;
} 

static bool:SetTeleportEndPoint(client)
{
	decl Float:vAngles[3], Float:vOrigin[3];
	
	GetClientEyePosition(client,vOrigin);
	GetClientEyeAngles(client, vAngles);
	
	//get endpoint for teleport
	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
	
	if(TR_DidHit(trace))
	{
		decl Float:vBuffer[3], Float:vStart[3];

		TR_GetEndPosition(vStart, trace);
		GetVectorDistance(vOrigin, vStart, false);
		new Float:Distance = -35.0;
		GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);
		g_pos[0] = vStart[0] + (vBuffer[0]*Distance);
		g_pos[1] = vStart[1] + (vBuffer[1]*Distance);
		g_pos[2] = vStart[2] + (vBuffer[2]*Distance);
	}
	else
	{
		PrintToChat(client, "[SM] %s", "Could not teleport player after respawn");
		CloseHandle(trace);
		return false;
	}
	CloseHandle(trace);
	return true;
}

PerformTeleport(client, target, Float:pos[3])
{
	pos[2]+=40.0;
	TeleportEntity(target, pos, NULL_VECTOR, NULL_VECTOR);
	
	LogAction(client,target, "\"%L\" teleported \"%L\" after respawning him" , client, target);
}

stock CheatCommand(client, String:command[], String:arguments[]="")
{
	new userflags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userflags);
}