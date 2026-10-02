// 燕云十六声后期处理 Volume 配置脚本
// 一键配置:青冥色调 + 克制 Bloom + 远景虚化 + Vignette + 胶片颗粒
// 用法:挂在空 GameObject 上,自动创建 Global Volume + 配置 overrides
#if UNITY_URP_INSTALLED || UNITY_6000_0_OR_NEWER
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Dingfengbo.Environment
{
    [RequireComponent(typeof(Volume))]
    public class YanYunVolume : MonoBehaviour
    {
        [Header("青冥色调")]
        [SerializeField, ColorUsage(false, true)] Color青冥 = new(0.78f, 0.83f, 0.84f, 1f);
        [SerializeField, Range(-50, 50)] float saturation = -25;       // 全局去饱和
        [SerializeField, Range(-100, 100)] float temperature = -10;    // 偏冷
        [SerializeField, Range(-100, 100)] float tint = 8;              // 青绿偏移
        [SerializeField, Range(-100, 100)] float hueShift = 0;

        [Header("Bloom(克制)")]
        [SerializeField, Range(0, 2)] float bloomIntensity = 0.35f;
        [SerializeField, Range(0, 1)] float bloomThreshold = 0.9f;
        [SerializeField, ColorUsage(false, true)] Color bloomColor = Color.white;

        [Header("远景虚化(Depth of Field)")]
        [SerializeField] bool enableDoF = true;
        [SerializeField] float focusDistance = 8f;
        [SerializeField] float focusRange = 5f;
        [SerializeField] float blurFarDistance = 30f;

        [Header("Vignette(聚焦中心)")]
        [SerializeField, Range(0, 1)] float vignetteIntensity = 0.4f;
        [SerializeField, Range(0.1f, 5)] float vignetteSmoothness = 0.5f;
        [SerializeField, ColorUsage(false, true)] Color vignetteColor = new(0.08f, 0.10f, 0.12f, 1f);

        [Header("胶片颗粒")]
        [SerializeField, Range(0, 1)] float filmGrainIntensity = 0.15f;
        [SerializeField] FilmGrain.Lookup filmGrainType = FilmGrain.Lookup.Medium2;

        [Header("色差(极弱)")]
        [SerializeField, Range(0, 1)] float chromaticAberrationIntensity = 0.05f;

        Volume _volume;

        void Awake()
        {
            _volume = GetComponent<Volume>();
            if (_volume == null) _volume = gameObject.AddComponent<Volume>();
            _volume.isGlobal = true;
            _volume.priority = 1;
            BuildProfile();
        }

        // 在 Edit/Play 模式下都可调用
        public void BuildProfile()
        {
            var profile = ScriptableObject.CreateInstance<VolumeProfile>();
            profile.name = "YanYun_Look";

            // Color Adjustments(青冥)
            var ca = profile.Add<ColorAdjustments>(true);
            ca.active = true;
            ca.colorFilter.Override(青冥);
            ca.saturation.Override(saturation);
            ca.temperature.Override(temperature);
            ca.tint.Override(tint);
            ca.hueShift.Override(hueShift);
            ca.postExposure.Override(0.05f);
            ca.contrast.Override(8);

            // White Balance(强化冷调)
            var wb = profile.Add<WhiteBalance>(true);
            wb.active = true;
            wb.temperature.Override(temperature * 0.6f);
            wb.tint.Override(tint * 0.6f);

            // Bloom
            var bloom = profile.Add<Bloom>(true);
            bloom.active = true;
            bloom.intensity.Override(bloomIntensity);
            bloom.threshold.Override(bloomThreshold);
            bloom.tint.Override(bloomColor);
            bloom.highQualityFilter.Override(true);

            // Depth of Field(远景虚化)
            var dof = profile.Add<DepthOfField>(true);
            dof.active = enableDoF;
            dof.focusDistance.Override(focusDistance);
            dof.focusRange.Override(focusRange);
            dof.focalLength.Override(50);
            dof.gaussianStart.Override(blurFarDistance);
            dof.gaussianEnd.Override(blurFarDistance + 25f);
            dof.gaussianMaxRadius.Override(1f);
            dof.highQualitySampling.Override(true);

            // Vignette
            var vig = profile.Add<Vignette>(true);
            vig.active = true;
            vig.intensity.Override(vignetteIntensity);
            vig.smoothness.Override(vignetteSmoothness);
            vig.color.Override(vignetteColor);

            // Film Grain
            var grain = profile.Add<FilmGrain>(true);
            grain.active = true;
            grain.intensity.Override(filmGrainIntensity);
            grain.type.Override(filmGrainType);

            // Chromatic Aberration
            var ca2 = profile.Add<ChromaticAberration>(true);
            ca2.active = true;
            ca2.intensity.Override(chromaticAberrationIntensity);

            // Tonemapping ACES(电影感)
            var tm = profile.Add<Tonemapping>(true);
            tm.active = true;
            tm.mode.Override(TonemappingMode.ACES);

            _volume.profile = profile;
        }
    }
}
#endif
