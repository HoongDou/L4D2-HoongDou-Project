#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <left4dhooks>
#define ZC_SMOKER               1
#define ZC_BOOMER               2
#define ZC_HUNTER               3
#define ZC_SPITTER              4
#define ZC_JOCKEY               5
#define ZC_CHARGER              6
#define ZC_WITCH                7
#define ZC_TANK                 8
new iDidDamage[MAXPLAYERS + 1];
new KillInfected[MAXPLAYERS+1];
new KillSpecial[MAXPLAYERS+1];
new FriendDamage[MAXPLAYERS+1];
new DamageFriend[MAXPLAYERS+1];
public void OnPluginStart()
{
	RegConsoleCmd("sm_mvp", MVPinfo);
	RegConsoleCmd("sm_kills", MVPinfo);
	HookEvent("player_death", player_death);
	HookEvent("infected_death", infected_death);
	HookEvent("player_hurt",Event_PlayerHurt);
	HookEvent("round_start", event_RoundStart);
	HookEvent("map_transition", EventHook:ChangeVersus, EventHookMode_PostNoCopy);
	HookEvent("round_end", EventHook:ChangeVersus, EventHookMode_PostNoCopy);
	HookEvent("finale_win", EventHook:ChangeVersus, EventHookMode_PostNoCopy);
}
public event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{ 
		KillInfected[i] = 0; 
		KillSpecial[i] = 0; 
		FriendDamage[i] =0 ;
		DamageFriend[i] =0 ;
		iDidDamage[i] = 0;
	}
}

public Action:ChangeVersus(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("\x03[药役MVP统计]");
	SetConVarString(FindConVar("mp_gamemode"), "realism");
	displaykillinfected();
	for (new client = 1; client <= MaxClients; client++) 
	{
		if (IsInfected(client)) 
		{
			ChangeClientTeam(client, 1); 
		}
	}
}
public Action:MVPinfo(client, args) 
{
	PrintToChatAll("\x03[药役MVP统计]",client);
	displaykillinfected();
	return Plugin_Handled;
}
public Action:Event_PlayerHurt( Handle:event, const String:name[], bool:dontBroadcast )
{
	new zombieClass = 0;
    new victimId = GetEventInt(event, "userid");
    new victim = GetClientOfUserId(victimId);
    new attackerId = GetEventInt(event, "attacker");
    new attacker = GetClientOfUserId(attackerId);
    new damageDone = GetEventInt(event, "dmg_health");
	
	if(IsValidClient(victim) && IsValidClient(attacker) && GetClientTeam(attacker)==2 && GetClientTeam(victim)== 2 && GetEntProp(victim, Prop_Send, "m_isIncapacitated") < 1)
	{
		FriendDamage[attacker]+=damageDone;
		DamageFriend[victim]+=damageDone;
	}
	if (victimId && attackerId && IsClientAndInGame(victim) && IsClientAndInGame(attacker))
    {
        if (GetClientTeam(attacker) == 2 && GetClientTeam(victim) == 3)
        {
			zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
			if (zombieClass >= ZC_SMOKER && zombieClass < ZC_WITCH)
            {
				if (zombieClass == ZC_SMOKER && damageDone > 250)
				{
					damageDone = 250;
				}
				if (zombieClass == ZC_HUNTER && damageDone > 250)
				{
					damageDone = 250;
				} 
				if (zombieClass == ZC_BOOMER && damageDone > 50)
				{
					damageDone = 50;
				} 
				if (zombieClass == ZC_CHARGER && damageDone > 600)
				{
					damageDone = 600;
				} 
				if (zombieClass == ZC_SPITTER && damageDone > 100)
				{
					damageDone = 100;
				} 
				if (zombieClass == ZC_JOCKEY && damageDone > 325)
				{
					damageDone = 325;
				} 
				iDidDamage[attacker] += damageDone;
			}
        }
    }
}
public Action:infected_death(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(IsValidClient(attacker) && GetClientTeam(attacker) == 2)
	{
		KillInfected[attacker] += 1;
	}
}
public Action:player_death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsValidClient(attacker) && IsValidClient(client))
	{
		if(GetClientTeam(attacker) == 2 && GetClientTeam(client) == 3)
		{
			KillSpecial[attacker] += 1;
		}
	}
}
displaykillinfected()
{
	new client;
	new players;
	new players_clients[MAXPLAYERS+1];
	for (client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2) 
			players_clients[players++] = client;
	}
	SortCustom1D(players_clients, 4, SortByDamageDesc);
	for (new i; i <= 4; i++)
	{
		client = players_clients[i];
		if (IsValidClient(client) && GetClientTeam(client) == 2) 
		{
			PrintToChatAll("\x03特感\x04%2d \x03丧尸\x04%3d \x03黑/被黑\x04%2d/%2d \x03伤害\x04%4d \x05%N",KillSpecial[client], KillInfected[client],FriendDamage[client],DamageFriend[client],iDidDamage[client], client);
		}
	}
}
public SortByDamageDesc(elem1, elem2, const array[], Handle:hndl)
{
	if (iDidDamage[elem1] > iDidDamage[elem2]) return -1;
	else if (iDidDamage[elem2] > iDidDamage[elem1]) return 1;
	else if (elem1 > elem2) return -1;
	else if (elem2 > elem1) return 1;
	return 0;
}
stock bool:IsValidClient(client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}
stock bool:IsClientAndInGame(index)
{
    return (index > 0 && index <= MaxClients && IsClientInGame(index));
}
stock bool:IsClientInGameEx(client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{return true;} else {return false;}
}
stock bool:IsInfected(client) 
{
	if(IsClientInGame(client) && GetClientTeam(client) == 3) 
	{
		return true;
	} 
	else 
	{
		return false;
	}
}