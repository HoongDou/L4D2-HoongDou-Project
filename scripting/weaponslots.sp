#include <sourcemod>
#include <sdktools>
#include <l4d2_weapon_stocks_sis>


//测试命令
void RegisterCmds()
{
    RegConsoleCmd("sm_ws", Command_WeaponSlot,"fuck off");
}

public OnPluginStart()
{
	RegisterCmds()
}
public Action:Command_WeaponSlot(int client,int args)
{
    new weapon = GetPlayerWeaponSlot(client, _:L4D2WeaponSlot_Secondary);
    if (IsPistol(weapon)){
        PrintToChatAll("HAS PISTOL");
    }
    else {
        PrintToChatAll("NO PISTOL");
    }
}

bool:IsPistol(weapon)
{
    new WeaponId:wepid = IdentifyWeapon(weapon);
    return (wepid == WEPID_PISTOL || wepid == WEPID_PISTOL_MAGNUM);
}