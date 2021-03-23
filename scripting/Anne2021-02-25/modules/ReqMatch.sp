#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define			RM_DEBUG					0

#define			RM_DEBUG_PREFIX			"[ReqMatch]"

const	Float:	MAPRESTARTTIME			= 3.0;
const	Float:	RESETMINTIME			= 60.0;

new		bool:	RM_bMatchRequest[2];
new		bool:	RM_bIsMatchModeLoaded;
new		bool:	RM_bIsAMatchActive;
new		bool:	RM_bIsPluginsLoaded;
new		bool:	RM_bIsMapRestarted;
new		Handle:	RM_hDoRestart;
new		Handle:	RM_hAllowVoting;
new		Handle:	RM_hAllowCfgChange;
new		Handle:	RM_hReloaded;
new		Handle:	RM_hAutoLoad;
new		Handle:	RM_hAutoCfg;
new		Handle: RM_hFwdMatchLoad;
new		Handle: RM_hFwdMatchUnload;

RM_OnModuleStart()
{
	RM_hDoRestart			= CreateConVarEx("match_restart"		, "0", "Sets whether the plugin will restart the map upon match mode being forced or requested");
	RM_hAllowVoting			= CreateConVarEx("match_allowvoting"	, "1", "Sets whether players can vote/request for match mode");
	RM_hAllowCfgChange		= CreateConVarEx("match_allowcfgchange"	, "0", "Allow players to request match mode be restarted with a new config");
	RM_hAutoLoad			= CreateConVarEx("match_autoload"		, "0", "Has match mode start up automatically when a player connects and the server is not in match mode");
	RM_hAutoCfg				= CreateConVarEx("match_autoconfig"		, "", "Specify which config to load if the autoloader is enabled");
	
	//RegConsoleCmd("sm_match", RM_Cmd_Match);
	RegAdminCmd("sm_forcematch",	RM_Cmd_ForceMatch, ADMFLAG_CONFIG, "Forces the game to use match mode");
	RegAdminCmd("sm_fm",	RM_Cmd_ForceMatch, ADMFLAG_CONFIG, "Forces the game to use match mode");
	RegAdminCmd("sm_resetmatch",	RM_Cmd_ResetMatch, ADMFLAG_CONFIG, "Forces match mode to turn off REGRADLESS for always on or forced match");
	
	RM_hReloaded = FindConVarEx("match_reloaded");
	if(RM_hReloaded == INVALID_HANDLE)
	{
		RM_hReloaded = CreateConVarEx("match_reloaded", "0", "DONT TOUCH THIS CVAR! This is to prevent match feature keep looping, however the plugin takes care of it. Don't change it!",FCVAR_DONTRECORD|FCVAR_UNLOGGED);
	}
	
	new bool:bIsReloaded = GetConVarBool(RM_hReloaded);
	if(bIsReloaded)
	{
		if(RM_DEBUG || IsDebugEnabled())
			LogMessage("%s Plugin was reloaded from match mode, executing match load",RM_DEBUG_PREFIX);
		
		RM_bIsPluginsLoaded = true;
		SetConVarInt(RM_hReloaded,0);
		RM_Match_Load();
	}
}

RM_APL()
{
	RM_hFwdMatchLoad = CreateGlobalForward("LGO_OnMatchModeLoaded", ET_Event);
	RM_hFwdMatchUnload = CreateGlobalForward("LGO_OnMatchModeUnloaded", ET_Event);
	CreateNative("LGO_IsMatchModeLoaded", native_IsMatchModeLoaded);

}

public native_IsMatchModeLoaded(Handle:plugin, numParams)
{
	return RM_bIsMatchModeLoaded;
}

RM_OnMapStart()
{
	if(!RM_bIsMatchModeLoaded) return;
	
	if(RM_DEBUG || IsDebugEnabled())
		LogMessage("%s New map, executing match config...",RM_DEBUG_PREFIX);
	
	
	RM_Match_Load();
}

RM_OnClientPutInServer()
{
	if (!GetConVarBool(RM_hAutoLoad) || RM_bIsAMatchActive) return;
	
	decl String:buffer[128];
	GetConVarString(RM_hAutoCfg, buffer, sizeof(buffer));
	
	RM_UpdateCfgOn(buffer);
	RM_Match_Load();
}

RM_Match_Load()
{
	if(RM_DEBUG || IsDebugEnabled())
		LogMessage("%s Match Load",RM_DEBUG_PREFIX);
	
	if(!RM_bIsAMatchActive)
	{
		RM_bIsAMatchActive = true;
	}
	
	if(!RM_bIsPluginsLoaded)
	{
		if(RM_DEBUG || IsDebugEnabled())
			LogMessage("%s Loading plugins and reload self",RM_DEBUG_PREFIX);
		
		
		SetConVarInt(RM_hReloaded,1);
		ExecuteCfg("confogl_plugins.cfg");
		return;
	}
	
	ExecuteCfg("confogl.cfg");
	if(RM_DEBUG || IsDebugEnabled())
		LogMessage("%s Match config executed",RM_DEBUG_PREFIX);
	
	if(RM_bIsMatchModeLoaded) return;
	
	if(RM_DEBUG || IsDebugEnabled())
		LogMessage("%s Setting match mode active",RM_DEBUG_PREFIX);
	
	RM_bIsMatchModeLoaded = true;
	IsPluginEnabled(true,true);
	
	PrintToChatAll("\x01[\x05Confogl\x01] 加载模式配置");
	
	if(!RM_bIsMapRestarted && GetConVarBool(RM_hDoRestart))
	{
		PrintToChatAll("\x01[\x05Confogl\x01] 重新启动地图");
		CreateTimer(MAPRESTARTTIME,RM_Match_MapRestart_Timer);
	}
	
	if(RM_DEBUG || IsDebugEnabled())
		LogMessage("%s Match mode loaded!",RM_DEBUG_PREFIX);
	Call_StartForward(RM_hFwdMatchLoad);
	Call_Finish();	
}

RM_Match_Unload(bool:bForced=false)
{
	if(!IsHumansOnServer() || bForced)
	{
		if(RM_DEBUG || IsDebugEnabled())
			LogMessage("%s Match ís no longer active, IsHumansOnServer %b, bForced %b",RM_DEBUG_PREFIX,IsHumansOnServer(),bForced);
		
		RM_bIsAMatchActive = false;
	}
	
	if(IsHumansOnServer() && !bForced) return;
	
	if(RM_DEBUG || IsDebugEnabled())
		LogMessage("%s Unloading match mode...",RM_DEBUG_PREFIX);
	
	
	RM_bIsMatchModeLoaded = false;
	IsPluginEnabled(true,false);
	RM_bIsMapRestarted = false;
	RM_bIsPluginsLoaded = false;
	
	Call_StartForward(RM_hFwdMatchUnload);
	Call_Finish();	

	PrintToChatAll("\x01[\x05Confogl\x01] 卸载模式配置");
	
	ExecuteCfg("confogl_off.cfg");
	
	if(RM_DEBUG || IsDebugEnabled())
		LogMessage("%s Match mode unloaded!",RM_DEBUG_PREFIX);
	
}

public Action:RM_Match_MapRestart_Timer(Handle:timer)
{
	if(RM_DEBUG || IsDebugEnabled())
		LogMessage("%s Restarting map...",RM_DEBUG_PREFIX);
	
	decl String:sBuffer[128];
	GetCurrentMap(sBuffer,sizeof(sBuffer));
	ServerCommand("changelevel %s",sBuffer);
	RM_bIsMapRestarted = true;
}

RM_UpdateCfgOn(const String:cfgfile[])
{
	if(SetCustomCfg(cfgfile))
	{
		PrintToChatAll("\x01[\x05Confogl\x01] 启用 \"\x04%s\x01\" 配置", cfgfile);
		if(RM_DEBUG || IsDebugEnabled())
		{
			LogMessage("%s Starting match on config %s", RM_DEBUG_PREFIX, cfgfile);
		}
	}
	else
	{
		PrintToChatAll("\x01[\x05Confogl\x01]  配置 \"\x04%s\x01\" 没有找到, 使用默认配置", cfgfile);
	}

}

public Action:RM_Cmd_ForceMatch(client, args)
{
	if(RM_DEBUG || IsDebugEnabled())
		LogMessage("%s Match mode forced to load!",RM_DEBUG_PREFIX);
		
	if(args > 0) // cfgfile specified
	{
		static String:sBuffer[128];
		GetCmdArg(1, sBuffer, sizeof(sBuffer));
		RM_UpdateCfgOn(sBuffer);
	}
	else
	{
		SetCustomCfg("");
	}
	
	if (RM_bIsMatchModeLoaded) RM_Match_Unload(true);
	RM_Match_Load();
	
	return Plugin_Handled;
}

public Action:RM_Cmd_ResetMatch(client,args)
{
	if(!RM_bIsMatchModeLoaded){return Plugin_Handled;}
	
	if(RM_DEBUG || IsDebugEnabled())
		LogMessage("%s Match mode forced to unload!",RM_DEBUG_PREFIX);
	
	
	RM_Match_Unload(true);
	
	return Plugin_Handled;
}

public Action:RM_Cmd_Match(client, args)
{
	if((!IsVersus() && !IsScavenge()) || !GetConVarBool(RM_hAllowVoting)){return Plugin_Handled;}
	
	
	new iTeam = GetClientTeam(client);
	if((iTeam == TEAM_SURVIVOR || iTeam == TEAM_INFECTED) && !RM_bMatchRequest[iTeam-2])
	{
		RM_bMatchRequest[iTeam-2] = true;
	}
	else
	{
		return Plugin_Handled;
	}
	
	if(RM_bMatchRequest[0] && RM_bMatchRequest[1])
	{
		PrintToChatAll("\x01[\x05Confogl\x01] 双方已同意启动一场正式比赛");
		if (RM_bIsMatchModeLoaded && GetConVarBool(RM_hAllowCfgChange)) RM_Match_Unload(true);
		RM_Match_Load();
	}
	else if(RM_bMatchRequest[0] || RM_bMatchRequest[1])
	{
		PrintToChatAll("\x01[\x05Confogl\x01] \x04%s \x01发起正式比赛模式. \x04%s \x01输入 \x04!match \x01接受",g_sTeamName[iTeam+4],g_sTeamName[iTeam+3]);
		if(args > 0) // cfgfile specified
		{
			static String:sBuffer[128];
			GetCmdArg(1, sBuffer, sizeof(sBuffer));
			RM_UpdateCfgOn(sBuffer);
		}
		else
		{
			SetCustomCfg("");
		}
		CreateTimer(30.0, RM_MatchRequestTimeout);
	}
	
	return Plugin_Handled;
}

public Action:RM_MatchRequestTimeout(Handle:timer){RM_ResetMatchRequest();}

public Action:RM_MatchResetTimer(Handle:timer)
{
	RM_Match_Unload();
}

RM_ResetMatchRequest()
{
	RM_bMatchRequest[0] = false;
	RM_bMatchRequest[1] = false;
}