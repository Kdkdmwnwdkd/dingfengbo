// 竹林场景生成器(燕云十六声风格)
// 程序化生成:竹竿垂直矩阵 + 雾气 + 青墨调色 + 三远法纵深
using UnityEngine;

namespace Dingfengbo.Environment
{
    public class BambooForest : MonoBehaviour
    {
        [Header("竹林")]
        [SerializeField] GameObject bambooPrefab; // 高瘦柱体或竹子模型
        [SerializeField] int count = 120;
        [SerializeField] float areaSize = 30f;
        [SerializeField] float minScale = 0.85f;
        [SerializeField] float maxScale = 1.4f;
        [SerializeField] bool useNoise = true;
        [SerializeField] float noiseFrequency = 0.3f;

        [Header("燕云调色")]
        [SerializeField] Color nearTint = new(0.55f, 0.65f, 0.6f, 1f);  // 近景深青
        [SerializeField] Color farTint = new(0.40f, 0.50f, 0.55f, 1f);  // 远景淡青
        [SerializeField] AnimationCurve tintByDistance;

        [Header("地面")]
        [SerializeField] GameObject groundPrefab;
        [SerializeField] Vector2 groundSize = new(40f, 40f);

        [Header("石头/植被")]
        [SerializeField] GameObject[] rocks;
        [SerializeField] int rockCount = 25;

        [Header("雾气(辅助控制)")]
        [SerializeField] float fogDensity = 0.045f;
        [SerializeField] Color fogColor = new(0.40f, 0.50f, 0.55f, 1f);

        void Start()
        {
            GenerateForest();
            SetupFog();
        }

        void GenerateForest()
        {
            // 地面
            if (groundPrefab != null)
            {
                var g = Instantiate(groundPrefab, transform);
                g.transform.position = transform.position;
                g.transform.localScale = new Vector3(groundSize.x, 1, groundSize.y);
                ApplyTint(g, nearTint);
            }

            // 竹子
            if (bambooPrefab == null)
            {
                Debug.LogWarning("[BambooForest] 未指定 bambooPrefab,跳过竹林生成");
                return;
            }

            for (int i = 0; i < count; i++)
            {
                Vector3 pos;
                if (useNoise)
                {
                    // Perlin noise 让竹林成簇,留出空地
                    Vector2 r = Random.insideUnitCircle * areaSize * 0.5f;
                    pos = transform.position + new Vector3(r.x, 0, r.y);
                    float n = Mathf.PerlinNoise(pos.x * noiseFrequency, pos.z * noiseFrequency);
                    if (n < 0.4f) continue; // 留出空地
                }
                else
                {
                    Vector2 r = Random.insideUnitCircle * areaSize * 0.5f;
                    pos = transform.position + new Vector3(r.x, 0, r.y);
                }

                var b = Instantiate(bambooPrefab, pos, Quaternion.Euler(0, Random.Range(0, 360f), 0), transform);
                float s = Random.Range(minScale, maxScale);
                b.transform.localScale = new Vector3(s, s * Random.Range(1.0f, 1.3f), s);

                // 按距离调色:近深远、远淡青
                float distFromCenter = Vector3.Distance(b.transform.position, transform.position) / (areaSize * 0.5f);
                Color tint = tintByDistance != null && tintByDistance.length > 0
                    ? Color.Lerp(nearTint, farTint, tintByDistance.Evaluate(distFromCenter))
                    : Color.Lerp(nearTint, farTint, distFromCenter);
                ApplyTint(b, tint);
            }

            // 石头
            if (rocks != null && rocks.Length > 0)
            {
                for (int i = 0; i < rockCount; i++)
                {
                    Vector2 r = Random.insideUnitCircle * areaSize * 0.45f;
                    var pos = transform.position + new Vector3(r.x, 0, r.y);
                    var rock = Instantiate(rocks[Random.Range(0, rocks.Length)], pos, Quaternion.Euler(0, Random.Range(0, 360f), 0), transform);
                    float s = Random.Range(0.5f, 1.5f);
                    rock.transform.localScale = Vector3.one * s;
                    ApplyTint(rock, nearTint);
                }
            }
        }

        void ApplyTint(GameObject obj, Color tint)
        {
            var renderers = obj.GetComponentsInChildren<Renderer>();
            foreach (var r in renderers)
            {
                foreach (var mat in r.materials)
                {
                    if (mat == null) continue;
                    if (mat.HasProperty("_BaseColor"))
                        mat.SetColor("_BaseColor", tint);
                    else if (mat.HasProperty("_Color"))
                        mat.SetColor("_Color", tint);
                }
            }
        }

        void SetupFog()
        {
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.Exponential;
            RenderSettings.fogDensity = fogDensity;
            RenderSettings.fogColor = fogColor;
            RenderSettings.fogStartDistance = 15f;
            RenderSettings.fogEndDistance = 80f;
        }

        void OnDestroy()
        {
            RenderSettings.fog = false;
        }
    }
}
