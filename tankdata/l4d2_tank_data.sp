#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>

int tank_id;
int KeyBuffer[MAXPLAYERS+1];

int AliveTime[MAXPLAYERS+1];
int claw[MAXPLAYERS+1];
int Tie[MAXPLAYERS+1];
int Throw[MAXPLAYERS+1];
public Plugin myinfo =
{
	name = "记录坦克的相关信息插件",
	description = "记录坦克的相关信息插件",
	author = "HoongDou",
	version = "1.5",
	url = ""
};

public void OnPluginStart()
{
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("tank_spawn",  Event_TankSpawn);
	HookEvent("ability_use", ability_use);
	//HookEvent("tank_killed", eTankKilled, EventHookMode_Pre);
	HookEvent("player_death",			Event_PlayerDeath);
	HookEvent("round_end",				Event_RoundEnd);
}

public Action Event_RoundEnd(Event event, const char[] event_name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i)  && GetEntProp(i, Prop_Send, "m_zombieClass") == 8 && GetClientTeam(i)==3  && IsPlayerAlive(i))
		{
			CPrintToChatAll("{blue}Tank {default}Still alive! Give: {olive}%d{default} Punch(s), {olive}%d{default} Rock(s), {olive}%d{default} Entities",claw[i],Throw[i],Tie[i]);
			AliveTime[i] = 0;
			claw[i] = 0;
			Tie[i] = 0;
			Throw[i] = 0;
		}
	}
	return Plugin_Handled;
}

public Action Event_PlayerDeath(Event event, const char []name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if(GetClientTeam(victim) == 3)
	{
		int iClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
		if(iClass == 8)
		{
			CPrintToChatAll("{default}[{green}!{default}] {blue}Tank {default}Survived {olive}%d{default} second(s) with: {olive}%d{default} Punch(s), {olive}%d{default} Rock(s), {olive}%d{default} Entities",AliveTime[victim],claw[victim],Throw[victim],Tie[victim]);
			AliveTime[victim] = 0;
			claw[victim] = 0;
			Tie[victim] = 0;
			Throw[victim] = 0;
		}
	}
	return Plugin_Handled;
}
/*
public eTankKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	new tank = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsValidPlayer(tank))
	{
		CPrintToChatAll("{default}[{green}!{default}] {blue}Tank {default}Survived {olive}%d{default} second(s) with: {olive}%d{default} Punch(s), {olive}%d{default} Rock(s), {olive}%d{default} Entities",AliveTime[tank],claw[tank],Throw[tank],Tie[tank]);
		AliveTime[tank] = 0;
		claw[tank] = 0;
		Tie[tank] = 0;
		Throw[tank] = 0;
	}
}
*/

public Action OnPlayerRunCmd(int Client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if ( GetEntProp(Client, Prop_Send, "m_zombieClass") == 8 && GetClientTeam(Client)==3  && IsPlayerAlive(Client))
	{
		if((buttons & IN_ATTACK) && !(KeyBuffer[Client] & IN_ATTACK))
		{
			
		}
		KeyBuffer[Client]=buttons;
	}
    return Plugin_Continue;
}

public Action Event_TankSpawn(Event event, const char [] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsValidPlayer(client) && IsPlayerAlive(client))
	{
		AliveTime[client] = 0;
		claw[client] = 0;
		Tie[client] = 0;
		Throw[client] = 0;
		CreateTimer(1.0,AliveTime_save,GetClientUserId(client),TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);	
	}
	return Plugin_Handled;
}

public Action AliveTime_save(Handle timer,any userid)
{
	int Client = GetClientOfUserId(userid);
	if(!IsValidPlayer(Client) || !IsPlayerAlive(Client)) return Plugin_Stop;
	AliveTime[Client]++;
	return Plugin_Continue;
}

public Action ability_use(Event event, const char[] name, bool dontBroadcast)
{
	char s[32];
	GetEventString(event, "ability", s, 32);
	if(StrEqual(s, "ability_throw", true))
	{	
		tank_id = GetClientOfUserId(GetEventInt(event, "userid"));
	}
	return Plugin_Handled;
}
public void OnEntityCreated(int entity, const char []classname)
{
	if(IsValidEdict(entity) && StrEqual(classname, "tank_rock", true) && GetEntProp(entity, Prop_Send, "m_iTeamNum")>=0)
	{
		if(IsValidPlayer(tank_id)) 
		{
			tank_id = 0;
		}
	}
}
	
public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int entity = GetEventInt(event, "attacker");
	int attacker = GetClientOfUserId(entity);
	int target = GetClientOfUserId(GetEventInt(event, "userid"));
	char weapon[64];
	GetEventString(event, "weapon", weapon, 64);
	if(IsValidPlayer(attacker) && IsValidPlayer(target) && IsPlayerAlive(target))
	{
		if(GetEntProp(attacker, Prop_Send, "m_zombieClass") == 8 && GetClientTeam(attacker)==3 && GetClientTeam(target)==2)
		{
			if( StrEqual(weapon, "tank_claw"))
			{
				claw[attacker]++;
			}
			else if(StrEqual(weapon, "tank_rock") )
			{
				Throw[attacker]++;
			}
			else Tie[attacker]++;
		}
	}
	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamagepre);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamagepre);
}

public Action OnTakeDamagepre(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, const float damageForce[3], const float damagePosition[3])
{
	if(	inflictor <= 0
	||	attacker <= 0
	||	attacker > MaxClients
	||	victim <= 0
	||	victim > MaxClients
	||	!IsValidEdict(inflictor)
	||	!IsClientInGame(attacker)
	||	!IsClientInGame(victim))
	{
		return Plugin_Continue;
	}
	
	if(victim == attacker)
	{
		return Plugin_Continue;
	}
	
	if(GetClientTeam(victim) == 2 && GetClientTeam(attacker) == 3 && GetEntProp(attacker, Prop_Send, "m_zombieClass")==8)
	{
		if(IsValidEdict(weapon))
		{
			char sClassname[32];
			GetEdictClassname(weapon, sClassname, sizeof(sClassname));
			PrintToChatAll("weapon:%s",sClassname);
		}
	}
	
	return Plugin_Continue;
}

stock bool IsCommonInfected(int iEntity)
{
	if(iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity))
	{
		char strClassName[64];
		GetEdictClassname(iEntity, strClassName, sizeof(strClassName));
		return StrEqual(strClassName, "infected");
	}
	return false;
}

stock bool IsValidPlayer(int Client, bool AllowBot = true, bool AllowDeath = true)
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