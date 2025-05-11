#include "StdAfx.h"
#include "Actor.h"
#include "actorcondition.h"
#include "bandage.h"

CBandage::CBandage() {}

CBandage::~CBandage() {}

bool CBandage::CanUseItem() const
{
	const float ConditionBandageUse = Actor()->conditions().BleedingSpeed();

	return (ConditionBandageUse < fis_zero(ConditionBandageUse, EPS)) ? false : true;
}

shared_str CBandage::GetUseString() const
{
	const shared_str nameActionXml = "st_bandage_not_used";
	const bool NewBandageOption = EngineExternal()[EEngineExternalGame::EnableUseBandage7DaysToDie];

	return (!this->CanUseItem() && NewBandageOption) ? nameActionXml.c_str() : CEatableItemObject::GetUseString();
}

using namespace luabind;

#pragma optimize("s",on)
void CBandage::script_register(lua_State *L)
{
	module(L)
	[
		class_<CBandage, CGameObject>("CBandage")
			.def(constructor<>())
	];
}
