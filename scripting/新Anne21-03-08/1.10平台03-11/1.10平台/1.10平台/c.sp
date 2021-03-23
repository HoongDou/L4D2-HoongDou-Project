#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
public void OnPluginStart()
{
	HookEvent("mission_lost", mission_lost);
}
public OnMapStart()
{
	PrecacheSound("sound/player/survivor/voice/producer/laughter13.wav");
}
public mission_lost(Handle:event, const String:name[], bool:dontBroadcast)
{
    EmitSoundToAll("sound/player/survivor/voice/producer/laughter13.wav");
}
