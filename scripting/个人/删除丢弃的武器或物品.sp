#include <sourcemod>
#include <sdktools>

new Handle:ClearTime = INVALID_HANDLE;
new Handle:g_timer = INVALID_HANDLE;
Address address[2048];
new aaa;

new String:file[PLATFORM_MAX_PATH];

new const String:ItemDeleteList[][] =
{
	"weapon_smg_silenced",//消音微冲
	"weapon_smg_mp5",//mp5突击抢
	"weapon_smg",//uzi冲锋枪
	"weapon_shotgun_chrome",//铬合金霰弹枪
	"weapon_pumpshotgun",//泵动式霰弹枪
	"weapon_hunting_rifle",//30连狙
	"weapon_rifle_m60",//M60重机枪
	"weapon_rifle_ak47",//AK步枪
	"weapon_rifle_desert",///SCAR突击步枪
	"weapon_rifle",//M16突击步枪
	"weapon_autoshotgun",//一代连喷
	"weapon_shotgun_spas",//二代连喷
	"weapon_sniper_military",//15连狙
	"weapon_sniper_awp",//AWP狙击步枪
	"weapon_rifle_sg552",//SG552突击步枪
	"weapon_sniper_scout",//鸟狙
	"weapon_grenade_launcher",//榴弹发射器
	"weapon_pistol_magnum",//马格楠
	"weapon_pistol",//小手枪
	"weapon_molotov",//燃烧瓶
	"weapon_pipe_bomb",//土制炸弹
	"weapon_vomitjar",//胆汁炸弹
	"first_aid_kit",//医疗包
	"defibrillator",//电击器
	"weapon_upgradepack_explosive",//高爆弹药升级包
	"weapon_upgradepack_incendiary",//燃烧弹药升级包
	"weapon_propanetank",//煤气罐
	"weapon_oxygentank",//氧气瓶
	"weapon_gnome",//圣诞老人
	"weapon_pain_pills",//止疼药
	"weapon_adrenaline",//肾上腺素
	"weapon_chainsaw",//电锯
	"weapon_melee",
	"knife",//小刀
	"baseball_bat",//棒球棒
	"katana",//武士刀
	"frying_pan",//铁锅
	"cricket_bat",//板球棒
	"electric_guitar",//电吉他
	"tonfa",//警棍
	"machete",//砍刀
	"fireaxe",//消防斧
	"crowbar",//撬棍
	"hunting_knife",//猎人刀
	"golfclub"//高尔夫球杆
};

public Plugin:myinfo = 
{
	name = "一定时间后删除丢弃的武器或物品，节省服务器资源开销，避免实体超出2048炸服",
	author = "",
	version = "1.0"
}

public OnPluginStart()
{
	BuildPath(Path_SM, file, sizeof(file), "logs/remove_drop_weapon.log");

	ClearTime = CreateConVar("sm_drop_clear_time", "60.0", "clear time", 0);
	
	HookEvent("weapon_drop", Event_Weapon_Drop);
	HookEvent("round_start", Event_Round_Start);
	HookEvent("round_end", Event_Round_End);
	HookEvent("player_disconnect", Event_Player_Disconnect); 
	
	AutoExecConfig(true, "clear_weapon_drop");
}

public OnMapEnd()
{
	if (g_timer != INVALID_HANDLE)
	{
		KillTimer(g_timer);
		g_timer = INVALID_HANDLE;
	}
}

public Action:Event_Player_Disconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"))
    if (!IsValidClient(client) || !IsPlayerAlive(client)) return Plugin_Stop;
    for(new i; i < 5; i++){
        new entity = GetPlayerWeaponSlot(client, i);
        if(entity <= 0 || entity <= MaxClients || !IsValidEntity(entity)){
            continue;
        }
        address[entity] = GetEntityAddress(entity);
        
        new String:item[32];
        GetEdictClassname(entity, item, sizeof(item));
        
        for(new j=0; j < sizeof(ItemDeleteList); j++)
        {
            if (StrContains(item, ItemDeleteList[j], false) != -1)
            {
                g_timer = CreateTimer(GetConVarFloat(ClearTime), del_weapon, EntIndexToEntRef(entity));
            }
        }
    }
    return Plugin_Stop;
} 

public Action:Event_Round_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	aaa = 1;
}

public Action:Event_Round_End(Handle:event, const String:name[], bool:dontBroadcast)
{
	aaa = 0;
}

public Action:Event_Weapon_Drop(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	if (!IsValidClient(client) || !IsPlayerAlive(client)) return Plugin_Stop;
		
	new entity = GetEventInt(event, "propid");
	address[entity] = GetEntityAddress(entity);
	
	new String:item[32];
	
	if (!IsValidEntity(entity) || !IsValidEdict(entity)) return Plugin_Stop;
	
	GetEdictClassname(entity, item, sizeof(item));
	
	for(new j=0; j < sizeof(ItemDeleteList); j++)
	{
		if (StrContains(item, ItemDeleteList[j], false) != -1)
		{
			g_timer = CreateTimer(GetConVarFloat(ClearTime), del_weapon, EntIndexToEntRef(entity));
		}
	}
	return Plugin_Stop;
}

public Action:del_weapon(Handle:timer, any:entity)
{
	if(entity && (entity = EntRefToEntIndex(entity)) != INVALID_ENT_REFERENCE)
	{
		if (IsValidEntity(entity) && aaa == 1)
		{
			if (address[entity] == GetEntityAddress(entity))
			{
				for(new j=0; j < sizeof(ItemDeleteList); j++)
				{
					new String:item[32];
					GetEdictClassname(entity, item, sizeof(item));
					 
					if (StrContains(item, ItemDeleteList[j], false) != -1)
					{
						if(!IsWeaponInUse(entity) && IsValidEntity(entity))
						{
							AcceptEntityInput(entity, "Kill");
							LogToFileEx(file, "remove drop weapon = %s", item);
							address[entity] = Address_Null;
							break;
						}
					}
				}
			}
		}
	}
	g_timer = INVALID_HANDLE;
}

bool:IsWeaponInUse(entity)
{	
	new client = GetEntPropEnt(entity, Prop_Data, "m_hOwner");
	if (IsValidClient(client))
		return true;
	
	client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	if (IsValidClient(client))
		return true;

	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsValidClient(i) && GetActiveWeapon(i) == entity)
			return true;
	}
	
	return false;
}

stock GetActiveWeapon(client)
{
	new weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if (!IsValidEntity(weapon)) 
	{
		return false;
	}
	
	return weapon;
}

stock bool:IsValidClient(client) 
{
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) return false;      
    return true; 
}