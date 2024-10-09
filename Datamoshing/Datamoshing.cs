using System;

namespace UnityEngine.Rendering.HighDefinition
{
    [Serializable, VolumeComponentMenu("Post-processing/Datamoshing")]
    public sealed class Datamoshing : CustomPostProcessVolumeComponent, IPostProcessComponent
    {
        public BoolParameter enable = new BoolParameter(false, true);

        [Tooltip("Size of compression macroblock")]
        public ClampedIntParameter blockSize = new ClampedIntParameter(32, 1, 128);
        [Tooltip("Entropy coefficient. The larger value makes the stronger noise")]
        public ClampedFloatParameter entropy = new ClampedFloatParameter(0.5f, 0.0f, 1.0f);
        [Tooltip("Scale factor for velocity vectors")]
        public ClampedFloatParameter velocityScale = new ClampedFloatParameter(0.8f, 0.0f, 2.0f);
        [Tooltip("Amount of random displacement")]
        public ClampedFloatParameter diffusion = new ClampedFloatParameter(0.4f, 0.0f, 2.0f);

        private Material m_Material = null;

        public bool IsActive()
        {
            return m_Material != null && blockSize.value > 0f && enable.value;
        }

        public override CustomPostProcessInjectionPoint injectionPoint => CustomPostProcessInjectionPoint.AfterPostProcess;

        private RenderTexture _workBuffer = null; // working buffer
        private RenderTexture _dispBuffer = null; // displacement buffer

        private bool _init = false;

        private static RenderTexture NewWorkBuffer(RenderTexture source)
        {
            return RenderTexture.GetTemporary(source.width, source.height);
        }

        private RenderTexture NewDispBuffer(RenderTexture source)
        {
            var rt = RenderTexture.GetTemporary(source.width / blockSize.value, source.height / blockSize.value, 0, RenderTextureFormat.ARGBHalf);
            rt.filterMode = FilterMode.Point;
            return rt;
        }

        private static void ReleaseBuffer(RenderTexture buffer)
        {
            if (buffer != null)
            {
                RenderTexture.ReleaseTemporary(buffer);
            }
        }

        public override void Setup()
        {
            if (Shader.Find("Hidden/Shader/Datamoshing") != null)
            {
                m_Material = new Material(Shader.Find("Hidden/Shader/Datamoshing"));
            }
        }

        public override void Render(CommandBuffer cmd, HDCamera camera, RTHandle source, RTHandle destination)
        {
            if (!enable.value || m_Material == null)
            {
                return;
            }

            m_Material.SetFloat("_BlockSize", blockSize.value);
            m_Material.SetFloat("_Quality", 1 - entropy.value);
            m_Material.SetFloat("_Velocity", velocityScale.value);
            m_Material.SetFloat("_Diffusion", diffusion.value);

            if (!_init)
            {
                // Start effect, initialize buffer
                _dispBuffer = NewDispBuffer(source);
                _workBuffer = NewWorkBuffer(source);

                // Simply blit the working buffer because motion vectors might not be ready (camera switch...)
                cmd.Blit(source, _workBuffer);
                cmd.Blit(_workBuffer, destination);
                cmd.Blit(null, _dispBuffer, m_Material, 0);

                _init = true;
            }
            else
            {
                // Update the displaceent buffer.
                RenderTexture newDisp = NewDispBuffer(source);
                cmd.Blit(_dispBuffer, newDisp, m_Material, 1);
                ReleaseBuffer(_dispBuffer);
                _dispBuffer = newDisp;

                // Moshing!
                RenderTexture newWork = NewWorkBuffer(source);
                m_Material.SetTexture("_WorkTex", _workBuffer);
                m_Material.SetTexture("_DispTex", _dispBuffer);
                cmd.Blit(source, newWork, m_Material, 2);
                ReleaseBuffer(_workBuffer);
                _workBuffer = newWork;

                // Result
                cmd.Blit(_workBuffer, destination);
            }
        }

        public override void Cleanup()
        {
            CoreUtils.Destroy(m_Material);

            ReleaseBuffer(_workBuffer);
            _workBuffer = null;

            ReleaseBuffer(_dispBuffer);
            _dispBuffer = null;

            _init = false;
        }
    }
}