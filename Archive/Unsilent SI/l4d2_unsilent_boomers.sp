#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

public Plugin:myinfo = 
{
	name = "L4D2-Unsilent-Boomers",
	author = "HoongDou",
	description = "Makes Boomers emit a sound to all players upon spawning, to nerf wallkicks a bit more.",
	version = "1.0.1",
	url = "https://github.com/HoongDou/L4D2-HoongDou-Project"
};

new String:g_aBoomerSounds[18][]= 
{
	"player/boomer/voice/alert/female_boomer_alert_04.wav",
	"player/boomer/voice/alert/female_boomer_alert_05.wav",
	"player/boomer/voice/alert/female_boomer_alert_07.wav",
	"player/boomer/voice/alert/female_boomer_alert_10.wav",
	"player/boomer/voice/alert/female_boomer_alert_11.wav",
	"player/boomer/voice/alert/female_boomer_alert_12.wav",
	"player/boomer/voice/alert/female_boomer_alert_13.wav",
	"player/boomer/voice/alert/female_boomer_alert_14.wav",
	"player/boomer/voice/alert/female_boomer_alert_15.wav",
	"player/boomer/voice/alert/male_boomer_alert_04.wav",
	"player/boomer/voice/alert/male_boomer_alert_05.wav",
	"player/boomer/voice/alert/male_boomer_alert_07.wav",
	"player/boomer/voice/alert/male_boomer_alert_10.wav",
	"player/boomer/voice/alert/male_boomer_alert_11.wav",
	"player/boomer/voice/alert/male_boomer_alert_12.wav",
	"player/boomer/voice/alert/male_boomer_alert_13.wav",
	"player/boomer/voice/alert/male_boomer_alert_14.wav",
	"player/boomer/voice/alert/male_boomer_alert_15.wav"
}

public OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawn_Event);
}


public OnMapStart()
{
	for (new i = 0; i < 18; i++)
	{
		PrefetchSound(g_aBoomerSounds[i]);
		PrecacheSound(g_aBoomerSounds[i], true);
	}
}

public Action:PlayBoomerSpawnSound(Handle:timer, client)
{
	if (!IsClientAndInGame(client)) 
		return Plugin_Handled;
		
	if (GetClientTeam(client) != 3) 
		return Plugin_Handled;
		
	if (!IsBoomer(client)) 
		return Plugin_Handled;
		
	if (!IsPlayerAlive(client)) 
		return Plugin_Handled;

	// Pick random Boomer sound and play it
	new randomSound = GetRandomInt(0, 17);
	EmitSoundToAll(g_aBoomerSounds[randomSound], client, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
	
	return Plugin_Continue;
}


public Action:PlayerSpawn_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	CreateTimer(0.1, PlayBoomerSpawnSound, client);

	return Plugin_Continue;
}

stock bool:IsBoomer(client)  
{
	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 2)
		return false;

	return true;
}

bool:IsClientAndInGame(index)
{
    return (index > 0 && index <= MaxClients && IsClientInGame(index));
}