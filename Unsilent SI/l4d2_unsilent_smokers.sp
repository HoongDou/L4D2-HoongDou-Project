#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

public Plugin:myinfo = 
{
	name = "L4D2-Unsilent-Smokers",
	author = "HoongDou",
	description = "Makes Smokers emit a sound to all players upon spawning, to nerf wallkicks a bit more.",
	version = "1.0.0",
	url = "https://github.com/HoongDou/L4D2-HoongDou-Project"
};

new String:g_aSmokerSounds[6][]= 
{
	"player/smoker/voice/alert/smoker_alert_01.wav",
	"player/smoker/voice/alert/smoker_alert_02.wav",
	"player/smoker/voice/alert/smoker_alert_03.wav",
	"player/smoker/voice/alert/smoker_alert_04.wav",
	"player/smoker/voice/alert/smoker_alert_05.wav",
	"player/smoker/voice/alert/smoker_alert_06.wav"
}

public OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawn_Event);
}


public OnMapStart()
{
	for (new i = 0; i < 6; i++)
	{
		PrefetchSound(g_aSmokerSounds[i]);
		PrecacheSound(g_aSmokerSounds[i], true);
	}
}

public Action:PlaySmokerSpawnSound(Handle:timer, client)
{
	if (!IsClientAndInGame(client)) 
		return Plugin_Handled;
		
	if (GetClientTeam(client) != 3) 
		return Plugin_Handled;
		
	if (!IsSmoker(client)) 
		return Plugin_Handled;
		
	if (!IsPlayerAlive(client)) 
		return Plugin_Handled;

	// Pick random smoker sound and play it
	new randomSound = GetRandomInt(0, 5);
	EmitSoundToAll(g_aSmokerSounds[randomSound], client, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
	
	return Plugin_Continue;
}


public Action:PlayerSpawn_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	CreateTimer(0.1, PlaySmokerSpawnSound, client);

	return Plugin_Continue;
}

stock bool:IsSmoker(client)  
{
	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 1)
		return false;

	return true;
}

bool:IsClientAndInGame(index)
{
    return (index > 0 && index <= MaxClients && IsClientInGame(index));
}