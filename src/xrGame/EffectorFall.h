#pragma once

#include "../xrEngine/Effector.h"

// приседание после падения
class CEffectorFall : public CEffectorCam
{
	float	fPower;
	float	fPhase;
public:
					CEffectorFall	(float power, float life_time=1);
	virtual BOOL	ProcessCam		(SCamEffectorInfo& info);
};

class CEffectorDOF : public CEffectorCam
{
	float			m_fPhase;
	bool m_bManualControl;
public:
					CEffectorDOF(const Fvector4& dof, bool bManualControl = false);
	virtual BOOL	ProcessCam		(SCamEffectorInfo& info);

	void Disable();
};
