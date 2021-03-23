#pragma newdecls required
#include <sourcemod>
#include <sdktools>

public void OnPluginStart()
{
	HookEvent("tank_spawn", mission_lost);
	HookEvent("mission_lost", mission_lost);
	// Sound Hook
	AddNormalSoundHook(SoundHook);
}
public void OnMapStart()
{
	PrecacheSound("player/survivor/voice/producer/laughter13.wav");
}
public void mission_lost(Event event, const char[] name, bool dont_broadcast)
{
    EmitSoundToAll("player/survivor/voice/producer/laughter13.wav");
}
public Action SoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (StrEqual(sample, "player/heartbeatloop.wav", false))
	{
		numClients = 0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}