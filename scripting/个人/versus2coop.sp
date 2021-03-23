#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
//#include <left4downtown>
#include <l4d2_saferoom_detect>

#pragma newdecls required

Handle gameMode;

int aliveClient = -1;

public void OnPluginStart()
{
	gameMode = FindConVar("mp_gamemode");
	HookEvent("door_close", Event_DoorClose, EventHookMode_Pre);
	HookEvent("player_incapacitated", Event_PlayerIncap, EventHookMode_Post);
	HookEvent("mission_lost",  Event_MissionLost, EventHookMode_Post);
	HookEvent("round_start",  Event_RoundStart, EventHookMode_Pre);
	//HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving, EventHookMode_Pre);
}

public Action Event_PlayerIncap(Handle event, const char[] name, bool dontBroadcast)
{
	if (IsTeamImmobilised())
	{
		SetCoop();
	}
}

public Action Event_DoorClose(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	bool checkpoint = GetEventBool(event, "checkpoint");
	if (checkpoint && client > 0)
	{
		aliveClient = client;
	}
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	if (aliveClient > 0 && SAFEDETECT_IsPlayerInEndSaferoom(aliveClient))
	{
		SetConVarString(gameMode, "coop");
	}
	else SetCoop();
	return Plugin_Handled;
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	SetConVarString(gameMode, "versus");
}
public Action Event_MissionLost(Handle event, const char[] name, bool dontBroadcast)
{
	SetCoop();
}

public void SetCoop()
{
	SetConVarString(gameMode, "coop");
}

public Action SetVersusTimer(Handle timer)
{
	SetConVarString(gameMode, "versus");
}

bool IsTeamImmobilised()
{
	bool bIsTeamImmobilised = true;
	int client = 1;
	while (client < MaxClients)
	{
		if (IsSurvivor(client) && IsPlayerAlive(client))
		{
			if (!IsIncapacitated(client))
			{
				bIsTeamImmobilised = false;
				return bIsTeamImmobilised;
			}
		}
		client++;
	}
	return bIsTeamImmobilised;
}

bool IsIncapacitated(int client)
{
	bool bIsIncapped;
	if (IsSurvivor(client))
	{
		if (0 < GetEntProp(client, view_as<PropType>(0), "m_isIncapacitated", 4, 0)) 
		{
			bIsIncapped = true;
		}
		if (!IsPlayerAlive(client))
		{
			bIsIncapped = true;
		}
	}
	return bIsIncapped;
}

bool IsSurvivor(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == 2;
}

bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client))
	{
		return false;
	}
	return IsClientInGame(client);
}