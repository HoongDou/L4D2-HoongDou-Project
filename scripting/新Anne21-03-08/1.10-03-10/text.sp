#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <smlib>
new Handle: g_hCvarInfectedTime = INVALID_HANDLE;
new Handle: g_hCvarInfectedLimit = INVALID_HANDLE;
new Handle: g_hCvarTankBhop = INVALID_HANDLE;
new Handle: g_hCvarWeapon = INVALID_HANDLE;
new Handle: g_hCvarSpawnMode = INVALID_HANDLE;
new Handle:hCvarCoop;
new CommonLimit; 
new CommonTime; 
new TankBhop;
new Weapon;
new SpawnMode;
public OnPluginStart()
{
	g_hCvarInfectedTime = FindConVar("versus_special_respawn_interval");
	g_hCvarInfectedLimit = FindConVar("l4d_infected_limit");
	g_hCvarTankBhop = FindConVar("ai_tank_bhop");
	g_hCvarWeapon = FindConVar("ZonemodWeapon");
	g_hCvarSpawnMode = FindConVar("z_infected_mode");
	HookConVarChange(g_hCvarInfectedTime, Cvar_InfectedTime);
	HookConVarChange(g_hCvarInfectedLimit, Cvar_InfectedLimit);
	HookConVarChange(g_hCvarTankBhop, CvarTankBhop);
	HookConVarChange(g_hCvarWeapon, CvarWeapon);
	HookConVarChange(g_hCvarSpawnMode, CvarSpawnMode);
	CommonTime = GetConVarInt(g_hCvarInfectedTime);
	CommonLimit = GetConVarInt(g_hCvarInfectedLimit);
	TankBhop = GetConVarInt(g_hCvarTankBhop);
	Weapon = GetConVarInt(g_hCvarWeapon);
	SpawnMode = GetConVarInt(g_hCvarSpawnMode);
	RegConsoleCmd("sm_xx",InfectedStatus);
	hCvarCoop = CreateConVar("coopmode", "0");
	HookEvent("player_incapacitated_start",Incap_Event);
	HookEvent("player_incapacitated",Incap_Event);
	HookEvent("round_start", event_RoundStart);
	//HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
	HookEvent("player_death", player_death);
	RegConsoleCmd("sm_zs", ZiSha);
	RegConsoleCmd("sm_kill", ZiSha);
}

public Action:player_death(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(IsTeamImmobilised())
	{
		SetConVarString(FindConVar("mp_gamemode"), "realism");
	}
	return Plugin_Continue;
}
public Action:ZiSha(client, args)
{
	ForcePlayerSuicide(client);
	if(IsTeamImmobilised())
	{
		SetConVarString(FindConVar("mp_gamemode"), "realism");
	}
	return Plugin_Handled;
}
/*
public Event_PlayerSpawn (Handle:event, const String:name[], bool:dontBroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) != 3)
	{
		FakeClientCommand(client, "sm_text");
	}
}
*/

public Ads_Menu(Handle:menu, MenuAction:action, param1, param2) {}

public Incap_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    new Incap = GetClientOfUserId(GetEventInt(event, "userid"));
	if(bool:GetConVarBool(hCvarCoop))
	{
		ForcePlayerSuicide(Incap);
	}
	if(IsTeamImmobilised())
	{
		SetConVarString(FindConVar("mp_gamemode"), "realism");
	}
}
public CvarSpawnMode( Handle:cvar, const String:oldValue[], const String:newValue[] ) 
{
	SpawnMode = GetConVarInt(g_hCvarSpawnMode);
}
public Cvar_InfectedTime( Handle:cvar, const String:oldValue[], const String:newValue[] ) 
{
	CommonTime = GetConVarInt(g_hCvarInfectedTime);
}
public Cvar_InfectedLimit( Handle:cvar, const String:oldValue[], const String:newValue[] ) 
{
	CommonLimit = GetConVarInt(g_hCvarInfectedLimit);
}
public CvarTankBhop( Handle:cvar, const String:oldValue[], const String:newValue[] ) 
{
	TankBhop = GetConVarInt(g_hCvarTankBhop);
}
public CvarWeapon( Handle:cvar, const String:oldValue[], const String:newValue[] ) 
{
	Weapon = GetConVarInt(g_hCvarWeapon);
}
public Action:InfectedStatus(Client, args)
{ 
	if(TankBhop > 0)
	{
		if( Weapon > 0)
		{
			if(SpawnMode > 0)
			PrintToChatAll("\x03武器配置\x05[\x04Zone\x05] \x03tank连跳\x05[\x04开启\x05] \x03特感刷新\x05[\x04阴%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
			else
			PrintToChatAll("\x03武器配置\x05[\x04Zone\x05] \x03tank连跳\x05[\x04开启\x05] \x03特感刷新\x05[\x04阳%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
		}
		else
		{
			if(SpawnMode > 0)
			PrintToChatAll("\x03武器配置\x05[\x04Anne\x05] \x03tank连跳\x05[\x04开启\x05] \x03特感刷新\x05[\x04阴%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
			else
			PrintToChatAll("\x03武器配置\x05[\x04Anne\x05] \x03tank连跳\x05[\x04开启\x05] \x03特感刷新\x05[\x04阳%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
		}
	}
	else
	{
		if( Weapon > 0)
		{
			if(SpawnMode > 0)
			PrintToChatAll("\x03武器配置\x05[\x04Zone\x05] \x03tank连跳\x05[\x04关闭\x05] \x03特感刷新\x05[\x04阴%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
			else
			PrintToChatAll("\x03武器配置\x05[\x04Zone\x05] \x03tank连跳\x05[\x04关闭\x05] \x03特感刷新\x05[\x04阳%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
		}
		else
		{
			if(SpawnMode > 0)
			PrintToChatAll("\x03武器配置\x05[\x04Anne\x05] \x03tank连跳\x05[\x04关闭\x05] \x03特感刷新\x05[\x04阴%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
			else
			PrintToChatAll("\x03武器配置\x05[\x04Anne\x05] \x03tank连跳\x05[\x04关闭\x05] \x03特感刷新\x05[\x04阳%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
		}
	}
	return Plugin_Handled;
}
public event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(TankBhop > 0)
	{
		if( Weapon > 0)
		{
			if(SpawnMode > 0)
			PrintToChatAll("\x03武器配置\x05[\x04Zone\x05] \x03tank连跳\x05[\x04开启\x05] \x03特感刷新\x05[\x04阴%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
			else
			PrintToChatAll("\x03武器配置\x05[\x04Zone\x05] \x03tank连跳\x05[\x04开启\x05] \x03特感刷新\x05[\x04阳%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
		}
		else
		{
			if(SpawnMode > 0)
			PrintToChatAll("\x03武器配置\x05[\x04Anne\x05] \x03tank连跳\x05[\x04开启\x05] \x03特感刷新\x05[\x04阴%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
			else
			PrintToChatAll("\x03武器配置\x05[\x04Anne\x05] \x03tank连跳\x05[\x04开启\x05] \x03特感刷新\x05[\x04阳%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
		}
	}
	else
	{
		if( Weapon > 0)
		{
			if(SpawnMode > 0)
			PrintToChatAll("\x03武器配置\x05[\x04Zone\x05] \x03tank连跳\x05[\x04关闭\x05] \x03特感刷新\x05[\x04阴%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
			else
			PrintToChatAll("\x03武器配置\x05[\x04Zone\x05] \x03tank连跳\x05[\x04关闭\x05] \x03特感刷新\x05[\x04阳%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
		}
		else
		{
			if(SpawnMode > 0)
			PrintToChatAll("\x03武器配置\x05[\x04Anne\x05] \x03tank连跳\x05[\x04关闭\x05] \x03特感刷新\x05[\x04阴%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
			else
			PrintToChatAll("\x03武器配置\x05[\x04Anne\x05] \x03tank连跳\x05[\x04关闭\x05] \x03特感刷新\x05[\x04阳%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
		}
	}
}
public OnClientPutInServer(Client)
{
	if (IsValidPlayer(Client, false))
	{
	if(TankBhop > 0)
	{
		if( Weapon > 0)
		{
			if(SpawnMode > 0)
			PrintToChat(Client,"\x03武器配置\x05[\x04Zone\x05] \x03tank连跳\x05[\x04开启\x05] \x03特感刷新\x05[\x04阴%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
			else
			PrintToChat(Client,"\x03武器配置\x05[\x04Zone\x05] \x03tank连跳\x05[\x04开启\x05] \x03特感刷新\x05[\x04阳%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
		}
		else
		{
			if(SpawnMode > 0)
			PrintToChat(Client,"\x03武器配置\x05[\x04Anne\x05] \x03tank连跳\x05[\x04开启\x05] \x03特感刷新\x05[\x04阴%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
			else
			PrintToChat(Client,"\x03武器配置\x05[\x04Anne\x05] \x03tank连跳\x05[\x04开启\x05] \x03特感刷新\x05[\x04阳%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
		}
	}
	else
	{
		if( Weapon > 0)
		{
			if(SpawnMode > 0)
			PrintToChat(Client,"\x03武器配置\x05[\x04Zone\x05] \x03tank连跳\x05[\x04关闭\x05] \x03特感刷新\x05[\x04阴%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
			else
			PrintToChat(Client,"\x03武器配置\x05[\x04Zone\x05] \x03tank连跳\x05[\x04关闭\x05] \x03特感刷新\x05[\x04阳%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
		}
		else
		{
			if(SpawnMode > 0)
			PrintToChat(Client,"\x03武器配置\x05[\x04Anne\x05] \x03tank连跳\x05[\x04关闭\x05] \x03特感刷新\x05[\x04阴%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
			else
			PrintToChat(Client,"\x03武器配置\x05[\x04Anne\x05] \x03tank连跳\x05[\x04关闭\x05] \x03特感刷新\x05[\x04阳%i特%i秒\x05] \x03!vote更改",CommonLimit,CommonTime);
		}
	}
	}
}
stock bool:IsValidPlayer(Client, bool:AllowBot = true, bool:AllowDeath = true)
{
	if (Client < 1 || Client > MaxClients)
		return false;
	if (!IsClientConnected(Client) || !IsClientInGame(Client))
		return false;
	if (!AllowBot)
	{
		if (IsFakeClient(Client))
			return false;
	}

	if (!AllowDeath)
	{
		if (!IsPlayerAlive(Client))
			return false;
	}	
	return true;
}
bool:IsTeamImmobilised() {
	//Check if there is still an upright survivor
	new bool:bIsTeamImmobilised = true;
	for (new client = 1; client < MaxClients; client++) {
		// If a survivor is found to be alive and neither pinned nor incapacitated
		// team is not immobilised.
		if (Survivor(client) && IsPlayerAlive(client) ) 
		{		
			if (!Incapacitated(client) ) 
			{		
				bIsTeamImmobilised = false;				
			} 
		}
	}
	return bIsTeamImmobilised;
}
stock bool:Survivor(i)
{
    return i > 0 && i <= MaxClients && IsClientInGame(i) && GetClientTeam(i) == 2;
}
stock bool:Incapacitated(client)
{
    new bool:bIsIncapped = false;
	if ( Survivor(client) ) {
		if (GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0) bIsIncapped = true;
		if (!IsPlayerAlive(client)) bIsIncapped = true;
	}
	return bIsIncapped;
}