using UnityEngine;

public class FonografoAudioController : MonoBehaviour
{
    [Header("Refs")]
    public AudioSource source;

    [Header("Clips (size 7 + 7)")]
    public AudioClip[] originales = new AudioClip[7];
    public AudioClip[] restaurados = new AudioClip[7];

    void Awake()
    {
        if (!source) source = GetComponent<AudioSource>();
    }

    void PlayClip(AudioClip clip)
    {
        if (!source || !clip) return;
        source.Stop();
        source.clip = clip;
        source.Play();
    }

    // Originales
    public void Play_O1() => PlayClip(originales[0]);
    public void Play_O2() => PlayClip(originales[1]);
    public void Play_O3() => PlayClip(originales[2]);
    public void Play_O4() => PlayClip(originales[3]);
    public void Play_O5() => PlayClip(originales[4]);
    public void Play_O6() => PlayClip(originales[5]);
    public void Play_O7() => PlayClip(originales[6]);

    // Restaurados
    public void Play_R1() => PlayClip(restaurados[0]);
    public void Play_R2() => PlayClip(restaurados[1]);
    public void Play_R3() => PlayClip(restaurados[2]);
    public void Play_R4() => PlayClip(restaurados[3]);
    public void Play_R5() => PlayClip(restaurados[4]);
    public void Play_R6() => PlayClip(restaurados[5]);
    public void Play_R7() => PlayClip(restaurados[6]);

    // Controles tipo Lydia
    public void Pause() { if (source) source.Pause(); }
    public void Stop()  { if (source) source.Stop();  }
}