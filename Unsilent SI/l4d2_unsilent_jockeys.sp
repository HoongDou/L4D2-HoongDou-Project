#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

public Plugin:myinfo = 
{
	name = "L4D2-Unsilent-Jockeys",
	author = "HoongDou",
	description = "Makes Jockeys emit a sound to all players upon spawning, to nerf wallkicks a bit more.",
	version = "1.0.0",
	url = "https://github.com/HoongDou/L4D2-HoongDou-Project"
};

new String:g_aJockeySounds[2][]= 
{
	"player/jockey/voice/alert/jockey_alert_02.wav",
	"player/jockey/voice/alert/jockey_alert_04.wav"
}

public OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawn_Event);
}


public OnMapStart()
{
	for (new i = 0; i < 2; i++)
	{
		PrefetchSound(g_aJockeySounds[i]);
		PrecacheSound(g_aJockeySounds[i], true);
	}
}

public Action:PlayJockeySpawnSound(Handle:timer, client)
{
	if (!IsClientAndInGame(client)) 
		return Plugin_Handled;
		
	if (GetClientTeam(client) != 3) 
		return Plugin_Handled;
		
	if (!IsJockey(client)) 
		return Plugin_Handled;
		
	if (!IsPlayerAlive(client)) 
		return Plugin_Handled;

	// Pick random jockey sound and play it
	new randomSound = GetRandomInt(1, 2);
	EmitSoundToAll(g_aJockeySounds[randomSound], client, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
	
	return Plugin_Continue;
}


public Action:PlayerSpawn_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	CreateTimer(0.1, PlayJockeySpawnSound, client);

	return Plugin_Continue;
}

stock bool:IsJockey(client)  
{
	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 5)
		return false;

	return true;
}

bool:IsClientAndInGame(index)
{
    return (index > 0 && index <= MaxClients && IsClientInGame(index));
}