#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

bool isJockey[MAXPLAYERS + 1] = false;

public Plugin myinfo = 
{
    name = "Musical Jockeys",
    author = "Jacob",
    description = "Prevents jockeys being able to spawn without making any noise.",
    version = "1.1",
    url = "github.com/jacob404/myplugins"
}

public void OnPluginStart()
{
    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnMapStart()
{
	PrecacheSound("music/bacteria/jockeybacterias.wav");
}
/*
public void L4D_OnEnterGhostState(int client)
{
    if (GetEntProp(client, Prop_Send, "m_zombieClass") == 5)
    {
        isJockey[client] = true;
    }
}
*/
public Action Event_PlayerSpawn(Handle event, char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
    if (GetEntProp(client, Prop_Send, "m_zombieClass") == 5)
    {
        isJockey[client] = true;
    }
	
    if (IsValidPlayer(client) && GetClientTeam(client) == 3 && isJockey[client])
    {
        EmitSoundToAll("music/bacteria/jockeybacterias.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
    }
    isJockey[client] = false;
}

bool IsValidPlayer(int client)
{
    if (client <= 0 || client > MaxClients) return false;
    if (!IsClientInGame(client)) return false;
    //if (IsFakeClient(client)) return false;
    return true;
}