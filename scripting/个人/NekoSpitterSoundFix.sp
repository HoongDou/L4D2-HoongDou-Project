#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <left4dhooks>

#define PLUGIN_VERSION "5.5NS"

bool IsSpitClient[MAXPLAYERS+1] = false;

public Plugin myinfo =
{
	name = "Neko Spitter SoundFix",
	description = "Neko Spitter SoundFix",
	author = "Neko Channel",
	version = PLUGIN_VERSION,
	url = "http://himeneko.cn"
};

public void OnPluginStart()
{
	HookEvent("player_hurt", Player_Hurt);
	HookEvent("spitter_killed", SpitterKilledEvent, EventHookMode_PostNoCopy);
}

public Action SpitterKilledEvent(Handle event, const char[] name, bool dontBroadcast)
{
	CreateTimer(1.0, FindDeathSpit);
}

public void OnMapStart()
{
	PrecacheSound("music/pzattack/enzymicide.wav", true);
	PrecacheSound("player/spitter/swarm/spitter_acid_loop_01.wav", true);
}

public Action FindDeathSpit(Handle timer)
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "insect_swarm")) != -1)
	{
		int maxFlames = L4D2Direct_GetInfernoMaxFlames(entity);
		int currentFlames = GetEntProp(entity, Prop_Send, "m_fireCount");

		if (maxFlames == 2 && currentFlames == 2)
		{
			SetEntProp(entity, Prop_Send, "m_fireCount", 1);
			L4D2Direct_SetInfernoMaxFlames(entity, 1);
		}
	}
}

public Action Player_Hurt(Handle event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int dmgtype = GetEventInt(event, "type");
	int attackerentid = GetEventInt(event, "attackerentid");
	char iClass[32];
	
	if(attackerentid <= 0 || !IsValidEdict(attackerentid))
		return Plugin_Continue;
	
	if(attacker == attackerentid)
		GetClientWeapon(attackerentid, iClass, sizeof(iClass));
	else
		GetEdictClassname(attackerentid, iClass, sizeof(iClass));
	
	if (IsValidClient(client) && GetClientTeam(client) == 2 && !IsSpitClient[client])
	{
		if(dmgtype == 263168 || dmgtype == 265216)
		{
			EmitSoundToClient(client, "music/pzattack/enzymicide.wav", client, 0);
			EmitSoundToClient(client, "player/spitter/swarm/spitter_acid_loop_01.wav", client, 0);
			IsSpitClient[client] = true;
			CreateTimer(3.0, Stop_Sound, client);
		}
		else if(StrEqual(iClass, "insect_swarm"))
		{
			EmitSoundToClient(client, "music/pzattack/enzymicide.wav", client, 0);
			EmitSoundToClient(client, "player/spitter/swarm/spitter_acid_loop_01.wav", client, 0);
			IsSpitClient[client] = true;
			CreateTimer(3.0, Stop_Sound, client);
		}
	}
	return Plugin_Continue;
}

public Action Stop_Sound(Handle timer, int client)
{
	if (IsValidClient(client))
	{
		IsSpitClient[client] = false;
		StopSound(client, 0, "music/pzattack/enzymicide.wav");
		StopSound(client, 0, "player/spitter/swarm/spitter_acid_loop_01.wav");
	}
	return Plugin_Continue;
}

stock bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

stock bool IsInfected(int client, int type)
{
	int class = GetEntProp(client, Prop_Send, "m_zombieClass");
	if(type == class)
		return true;
	return false;
}