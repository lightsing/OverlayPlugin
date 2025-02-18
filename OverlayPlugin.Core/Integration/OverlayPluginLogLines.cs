using System;
using System.Collections.Generic;
using System.IO;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using RainbowMage.OverlayPlugin.MemoryProcessors.Combatant;
using RainbowMage.OverlayPlugin.MemoryProcessors.ContentFinderSettings;
using RainbowMage.OverlayPlugin.MemoryProcessors.InCombat;
using RainbowMage.OverlayPlugin.Updater;
using MachinaRegion = System.String;
using OpcodeName = System.String;
using OpcodeVersion = System.String;

namespace RainbowMage.OverlayPlugin.NetworkProcessors
{
    class OverlayPluginLogLines
    {
        public OverlayPluginLogLines(TinyIoCContainer container)
        {
            container.Register(new OverlayPluginLogLineConfig(container));
            container.Register(new LineMapEffect(container));
            container.Register(new LineFateControl(container));
            container.Register(new LineCEDirector(container));
            container.Register(new LineInCombat(container));
            container.Register(new LineCombatant(container));
            container.Register(new LineRSV(container));
            container.Register(new LineActorCastExtra(container));
            container.Register(new LineAbilityExtra(container));
            container.Register(new LineContentFinderSettings(container));
            container.Register(new LineNpcYell(container));
            container.Register(new LineBattleTalk2(container));
            container.Register(new LineCountdown(container));
            container.Register(new LineCountdownCancel(container));
            container.Register(new LineActorMove(container));
            container.Register(new LineActorSetPos(container));
            container.Register(new LineSpawnNpcExtra(container));
            container.Register(new LineActorControlExtra(container));
            container.Register(new LineActorControlSelfExtra(container));
        }
    }

    class OverlayPluginLogLineConfig
    {
        private TinyIoCContainer container;
        private ILogger logger;
        private Dictionary<string, OpcodeConfigEntry> opcodes = new Dictionary<string, OpcodeConfigEntry>();
        public OverlayPluginLogLineConfig(TinyIoCContainer container)
        {
            this.container = container;
            logger = container.Resolve<ILogger>();
            opcodes.Add("CEDirector", new OpcodeConfigEntry { opcode = (uint)GameRepoInfo.CEDirectorOpcode, size = 16 });
            opcodes.Add("MapEffect", new OpcodeConfigEntry { opcode = (uint)GameRepoInfo.MapEffectOpcode, size = 11 });
            opcodes.Add("RSVData", new OpcodeConfigEntry { opcode = (uint)GameRepoInfo.RSVDataOpcode, size = 1080 });
            opcodes.Add("NpcYell", new OpcodeConfigEntry { opcode = (uint)GameRepoInfo.NpcYellOpcode, size = 32 });
            opcodes.Add("BattleTalk2", new OpcodeConfigEntry { opcode = (uint)GameRepoInfo.BattleTalk2Opcode, size = 40 });
            opcodes.Add("Countdown", new OpcodeConfigEntry { opcode = (uint)GameRepoInfo.CountdownOpcode, size = 48 });
            opcodes.Add("CountdownCancel", new OpcodeConfigEntry { opcode = (uint)GameRepoInfo.CountdownCancelOpcode, size = 40 });
            opcodes.Add("ActorMove", new OpcodeConfigEntry { opcode = (uint)GameRepoInfo.ActorMoveOpcode, size = 16 });
            opcodes.Add("ActorSetPos", new OpcodeConfigEntry { opcode = (uint)GameRepoInfo.ActorSetPosOpcode, size = 24 });
        }
        public IOpcodeConfigEntry this[string name]
        {
            get
            {
                return this[name];
            }
        }

        public IOpcodeConfigEntry this[string name, MachinaRegion machinaRegion]
        {
            get
            {
                var version = repository.GetGameVersion();
                if (version == null || version == "")
                {
                    LogException($"Could not detect game version from FFXIV_ACT_Plugin, defaulting to latest version for region {machinaRegion}");

                    var possibleVersions = new List<string>();
                    if (opcodesFile != null && opcodesFile.ContainsKey(machinaRegion))
                    {
                        foreach (var key in opcodesFile[machinaRegion].Keys)
                            possibleVersions.Add(key);
                    }

                    if (opcodesConfig != null && opcodesConfig.ContainsKey(machinaRegion))
                    {
                        foreach (var key in opcodesConfig[machinaRegion].Keys)
                            possibleVersions.Add(key);
                    }
                    possibleVersions.Sort();

                    if (possibleVersions.Count > 0)
                    {
                        version = possibleVersions[possibleVersions.Count - 1];
                        LogException($"Detected most recent version for {machinaRegion} = {version}");
                    }
                    else
                    {
                        LogException($"Could not determine latest version for region {machinaRegion}");
                        return null;
                    }
                }

                var opcode = GetOpcode(name, opcodesConfig, version, "config", machinaRegion);
                if (opcode == null)
                {
                    opcode = GetOpcode(name, opcodesFile, version, "file", machinaRegion);

                    // Try once to get this remotely, but only if this opcode or version is missing.
                    // TODO: we could consider getting this once always too, but for now
                    // if we ever have an incorrect (but present) opcode, another release is required.
                    if (opcode == null && !haveAttemptedOpcodeDownload)
                    {
                        haveAttemptedOpcodeDownload = true;
                        SaveRemoteOpcodesToConfig();
                        return GetOpcode(name, opcodesConfig, version, "config", machinaRegion);
                    }
                }

                return opcode;
            }
        }
    }
    interface IOpcodeConfigEntry
    {
        uint opcode { get; }
        uint size { get; }
    }

    [JsonObject(NamingStrategyType = typeof(Newtonsoft.Json.Serialization.DefaultNamingStrategy))]
    class OpcodeConfigEntry : IOpcodeConfigEntry
    {
        public uint opcode { get; set; }
        public uint size { get; set; }
    }
}
