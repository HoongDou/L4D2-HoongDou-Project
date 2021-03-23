//自杀 加入 旁观指令
//记录玩家聊天记录
//服务器没人时自动重启及重启指令
//Tank血量根据玩家数量设置
//特感血量根据玩家数量进行调整
//地图CVAR可用CFG单独设置
//玩家加入和离开提示
//特感受伤设置
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
//#include <left4downtown>
#include <sdktools_functions>
#define SCORE_DELAY_EMPTY_SERVER 3.0
#define L4D_MAXHUMANS_LOBBY_OTHER 3
new Float:lastDisconnectTime;
public SR_PluginStart()
{
	RegAdminCmd("sm_restart", RestartServer, ADMFLAG_ROOT, "Kicks all clients and restarts server");
}
public Action RestartServer(client,args)
{
    CrashServer();
}
public SR_ClientDisconnect(client) 
{  
	if (IsClientInGame(client) && IsFakeClient(client)) return;

	new Float:currenttime = GetGameTime();
	
	if (lastDisconnectTime == currenttime) return;
	
	CreateTimer(SCORE_DELAY_EMPTY_SERVER, IsNobodyConnected, currenttime);
	lastDisconnectTime = currenttime;
}
public Action:IsNobodyConnected(Handle:timer, any:timerDisconnectTime)
{
	if (timerDisconnectTime != lastDisconnectTime) return Plugin_Stop;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
			return  Plugin_Stop;
	}
	MYSQL_INITIP();
	Update_DATAIP();
	CrashServer();
	return  Plugin_Stop;
}