using UnityEngine;

public class AnimController : MonoBehaviour
{
    
    CharacterCore core;

    Animator animator;

    bool isStill = true;



    void Start()
    {
        core = GetComponentInParent<CharacterCore>();        
        animator = GetComponent<Animator>();
    }

    void Update()
    {
        if(Input.GetAxis("Trigger") < 0)
        {
            if(!IsClipCurrentlyPlaying(animator, "GunFired", 1))
                animator.Play("GunFired", 1);
        }
        IdleLegs();
    }

    void IdleLegs()
    {
        Vector3 localVel = transform.InverseTransformDirection(core.Rb.linearVelocity);
        float forwardVel = localVel.z;

        if(forwardVel != 0 && Input.GetAxis("Vertical") != 0)
        {
            if(!isStill)
            {
                isStill = true;
                if (animator != null && animator.GetBool("still") == false)
                {
                    animator.SetBool("still", true);
                }
            }
        }else
        {
            if (isStill)
            {
                isStill = false;
                if (animator != null && animator.GetBool("still") == true)
                {
                    animator.SetBool("still", false);
                }
            }
        }
    }

    bool IsClipCurrentlyPlaying(Animator animator, string clipName, int layer = 0)
    {
        AnimatorClipInfo[] clipInfo = animator.GetCurrentAnimatorClipInfo(layer);
        foreach (var info in clipInfo)
        {
            if (info.clip.name == clipName)
                return true;
        }
        return false;
    }


}

