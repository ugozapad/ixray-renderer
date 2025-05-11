#pragma once
#include "eatable_item_object.h"

class CBandage : public CEatableItemObject {
public:
    CBandage();
    ~CBandage() override;

    bool CanUseItem() const override;
    shared_str GetUseString() const override;

    DECLARE_SCRIPT_REGISTER_FUNCTION
};