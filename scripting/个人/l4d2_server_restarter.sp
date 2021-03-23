#include <sourcemod>

#define MAX_STR_LEN 128

 
public Plugin myinfo =
{
	name = "L4D2 server Restarter ",
	author = "Hoongdou",
	description = "Restarts server",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
    new ConVar:cvarHibernateWhenEmpty = FindConVar("sv_hibernate_when_empty");
    SetConVarInt(cvarHibernateWhenEmpty, 0, false, false);
    
    RegAdminCmd("sm_rs", KickClientsAndRestartServer, ADMFLAG_ROOT, "Kicks all clients and restarts server");
}

public Action KickClientsAndRestartServer(int client, int args)
{
    char kickMessage[MAX_STR_LEN];

    if (GetCmdArgs() >= 1) {
        GetCmdArgString(kickMessage, MAX_STR_LEN);
    } else {
        strcopy(kickMessage, MAX_STR_LEN, "Server is restarting")
    }

    for (new i = 1; i <= MaxClients; ++i) {
        if (IsHuman(i)) {
            KickClient(i, kickMessage); 
        }
    }

    CrashServer();
}

public bool HumanFound() 
{
    new bool:humanFound = false;
    new i = 1;

    while (!humanFound && i <= MaxClients) {
        humanFound = IsHuman(i);
        ++i;
    }

    return humanFound;
}

public bool IsHuman(client)
{
    return IsClientInGame(client) && !IsFakeClient(client);
}

public void CrashServer()
{
    PrintToServer("L4D2 Server Restarter: Crashing the server...");
    SetCommandFlags("crash", GetCommandFlags("crash")&~FCVAR_CHEAT);
    ServerCommand("crash");
}