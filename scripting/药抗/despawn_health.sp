#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

new Handle:si_restore_ratio;

public Plugin:myinfo = 
{
    name = "Despawn Health",
    author = "Jacob",
    description = "Gives Special Infected health back when they despawn.",
    version = "1.3",
    url = "github.com/jacob404/myplugins"
}

public OnPluginStart()
{
    si_restore_ratio = CreateConVar("si_restore_ratio", "0.5", "How much of the clients missing HP should be restored? 1.0 = Full HP");
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
    new MaxHealth = GetEntProp(client, Prop_Send, "m_iMaxHealth");
    if (CurrentHealth != MaxHealth)
    {
        SetEntityHealth(client, MaxHealth);
    }
}