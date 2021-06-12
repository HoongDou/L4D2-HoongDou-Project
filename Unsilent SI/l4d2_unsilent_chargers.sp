#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

public Plugin:myinfo = 
{
	name = "L4D2-Unsilent-Chargers",
	author = "HoongDou",
	description = "Makes Chargers emit a sound to all players upon spawning, to nerf wallkicks a bit more.",
	version = "1.0.1",
	url = "https://github.com/HoongDou/L4D2-HoongDou-Project"
};

new String:g_aChargerSounds[2][]= 
{
	"player/charger/voice/alert/charger_alert_01.wav",
	"player/charger/voice/alert/charger_alert_02.wav"
}

public OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawn_Event);
}


public OnMapStart()
{
	for (new i = 0; i < 2; i++)
	{
		PrefetchSound(g_aChargerSounds[i]);
		PrecacheSound(g_aChargerSounds[i], true);
	}
}

public Action:PlayChargerSpawnSound(Handle:timer, client)
{
	if (!IsClientAndInGame(client)) 
		return Plugin_Handled;
		
	if (GetClientTeam(client) != 3) 
		return Plugin_Handled;
		
	if (!IsCharger(client)) 
		return Plugin_Handled;
		
	if (!IsPlayerAlive(client)) 
		return Plugin_Handled;

	// Pick random charger sound and play it
	new randomSound = GetRandomInt(0, 1);
	EmitSoundToAll(g_aChargerSounds[randomSound], client, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
	
	return Plugin_Continue;
}


public Action:PlayerSpawn_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	CreateTimer(0.1, PlayChargerSpawnSound, client);

	return Plugin_Continue;
}

stock bool:IsCharger(client)  
{
	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 6)
		return false;

	return true;
}

bool:IsClientAndInGame(index)
{
    return (index > 0 && index <= MaxClients && IsClientInGame(index));
}