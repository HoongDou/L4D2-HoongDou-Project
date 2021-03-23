#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo = 
{
	name = "Tank Animation Accelerator", 
	author = "Lux, sorallll", 
	description = "", 
	version = "", 
	url = ""
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if(test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PostThinkPost, UpdateThink);
}

public void UpdateThink(int client)
{
	if(GetEntProp(client, Prop_Send, "m_zombieClass") != 8 || !IsPlayerAlive(client))
		return;
    
	switch(GetEntProp(client, Prop_Send, "m_nSequence", 2))
	{
		//这部分动画编号https://forums.alliedmods.net/showthread.php?t=319029
		case 54, 55, 56, 57, 58, 59, 60: //拍胸/咆哮
			SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", 999.0); //无实际意义的动画,设置一个较大的值也无影响

		case 17, 18, 19, 20, 21, 22, 23: //爬围栏/障碍
			SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", 2.5); //不能设置太高否则无法爬上去
	}
	
} 