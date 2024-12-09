#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

new tank_id;
new KeyBuffer[MAXPLAYERS+1];

new AliveTime[MAXPLAYERS+1];
new claw[MAXPLAYERS+1];
new Tie[MAXPLAYERS+1];
new Throw[MAXPLAYERS+1];
public Plugin:myinfo =
{
	name = "记录坦克的相关信息插件",
	description = "记录坦克的相关信息插件",
	author = "人生如梦",
	version = "1.0",
	url = "qq:791347186"
};

public OnPluginStart()
{
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("tank_spawn",  Event_TankSpawn);
	HookEvent("ability_use", ability_use);
	//HookEvent("tank_killed", eTankKilled, EventHookMode_Pre);
	HookEvent("player_death",			Event_PlayerDeath);
	HookEvent("round_end",				Event_RoundEnd);
}

public Action:Event_RoundEnd(Handle:event, String:event_name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i)  && GetEntProp(i, Prop_Send, "m_zombieClass") == 8 && GetClientTeam(i)==3  && IsPlayerAlive(i))
		{
			PrintToChatAll("拳:%d次,石头%d次,铁:%d次",claw[i],Throw[i],Tie[i]);
			AliveTime[i] = 0;
			claw[i] = 0;
			Tie[i] = 0;
			Throw[i] = 0;
		}
	}
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsValidPlayer(victim) && GetClientTeam(victim) == 3)
	{
		new iClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
		if(iClass == 8)
		{
			PrintToChatAll("存活:%d秒,拳:%d次,石头%d次,铁:%d次",AliveTime[victim],claw[victim],Throw[victim],Tie[victim]);
			AliveTime[victim] = 0;
			claw[victim] = 0;
			Tie[victim] = 0;
			Throw[victim] = 0;
		}
	}
}

public eTankKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	new tank = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsValidPlayer(tank))
	{
		PrintToChatAll("存活:%d秒,拳:%d次,石头%d次,铁:%d次",AliveTime[tank],claw[tank],Throw[tank],Tie[tank]);
		AliveTime[tank] = 0;
		claw[tank] = 0;
		Tie[tank] = 0;
		Throw[tank] = 0;
	}
}

public Action:OnPlayerRunCmd(Client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (IsValidPlayer(Client) && GetEntProp(Client, Prop_Send, "m_zombieClass") == 8 && GetClientTeam(Client)==3  && IsPlayerAlive(Client))
	{
		if((buttons & IN_ATTACK) && !(KeyBuffer[Client] & IN_ATTACK))
		{
			
		}
		KeyBuffer[Client]=buttons;
	}
}

public Action:Event_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsValidPlayer(client) && IsPlayerAlive(client))
	{
		AliveTime[client] = 0;
		claw[client] = 0;
		Tie[client] = 0;
		Throw[client] = 0;
		CreateTimer(1.0,AliveTime_save,GetClientUserId(client),TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);	
	}
}

public Action:AliveTime_save(Handle:timer,any:userid)
{
	new Client = GetClientOfUserId(userid);
	if(!IsValidPlayer(Client) || !IsPlayerAlive(Client)) return Plugin_Stop;
	AliveTime[Client]++;
	return Plugin_Continue;
}

public Action:ability_use(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:s[32];
	GetEventString(event, "ability", s, 32);
	if(StrEqual(s, "ability_throw", true))
	{	
		tank_id = GetClientOfUserId(GetEventInt(event, "userid"));
	}

}
public OnEntityCreated(entity, const String:classname[])
{
	if(IsValidEdict(entity) && StrEqual(classname, "tank_rock", true) && GetEntProp(entity, Prop_Send, "m_iTeamNum")>=0)
	{
		if(IsValidPlayer(tank_id)) 
		{
			tank_id = 0;
		}
	}
}
	
public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new entity = GetEventInt(event, "attacker");
	new attacker = GetClientOfUserId(entity);
	new target = GetClientOfUserId(GetEventInt(event, "userid"));
	decl String:weapon[64];
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
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamagepre);
}

public OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamagepre);
}

public Action:OnTakeDamagepre(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, const Float:damageForce[3], const Float:damagePosition[3])
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
			decl String:sClassname[32];
			GetEdictClassname(weapon, sClassname, sizeof(sClassname));
			PrintToChatAll("weapon:%s",sClassname);
		}
	}
	
	return Plugin_Continue;
}

stock bool:IsCommonInfected(iEntity)
{
	if(iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity))
	{
		decl String:strClassName[64];
		GetEdictClassname(iEntity, strClassName, sizeof(strClassName));
		return StrEqual(strClassName, "infected");
	}
	return false;
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