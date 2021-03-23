#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>

new Handle:hCvarSurvivorRespawnHealth;

public void:OnPluginStart()
{
	hCvarSurvivorRespawnHealth = FindConVar("z_survivor_respawn_health");
	SetCheatConVarInt(hCvarSurvivorRespawnHealth, 100);
	HookEvent("map_transition", ResetSurvivors, EventHookMode_PostNoCopy);
	HookEvent("round_freeze_end", ResetSurvivors, EventHookMode_PostNoCopy);
}

public void:OnPluginEnd()
{
	ResetConVar(hCvarSurvivorRespawnHealth, false, false);
}

public ResetSurvivors()
{
	RestoreHealth();
	ResetInventory();
	return Plugin_Continue;
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(client)
{
	RestoreHealth();
	return Plugin_Continue;
}

public RestoreHealth()
{
	new client = 1;
	while (client <= MaxClients)
	{
		if (IsSurvivor(client))
		{
			GiveItem(client, "health");
			SetEntPropFloat(client, PropType:0, "m_healthBuffer", 0.0, 0);
			SetEntProp(client, PropType:0, "m_currentReviveCount", any:0, 4, 0);
			SetEntProp(client, PropType:0, "m_bIsOnThirdStrike", any:0, 4, 0);
		}
		client++;
	}
	return Plugin_Continue;
}

public ResetInventory()
{
	new client;
	while (client <= MaxClients)
	{
		if (IsSurvivor(client))
		{
			new i;
			while (i < 5)
			{
				DeleteInventoryItem(client, i);
				i++;
			}
			GiveItem(client, "pistol");
		}
		client++;
	}
	return Plugin_Continue;
}

GiveItem(client, String:itemName[])
{
	new flags = GetCommandFlags("give");
	SetCommandFlags("give", flags ^ FCVAR_CHEAT);
	FakeClientCommand(client, "give %s", itemName);
	SetCommandFlags("give", flags);
	return Plugin_Continue;
}

DeleteInventoryItem(client, slot)
{
	new item = GetPlayerWeaponSlot(client, slot);
	if (0 < item)
	{
		RemovePlayerItem(client, item);
	}
	return Plugin_Continue;
}

bool:IsSurvivor(client)
{
	new var1;
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

SetCheatConVarInt(Handle:hCvarHandle, value)
{
	new cvarFlags = GetConVarFlags(hCvarHandle);
	SetConVarFlags(hCvarHandle, cvarFlags ^ FCVAR_CHEAT);
	SetConVarInt(hCvarHandle, value, false, false);
	SetConVarFlags(hCvarHandle, cvarFlags);
	return Plugin_Continue;
}
