using GLib;

namespace DVB {

    public enum DvbSrcCodeRate {
        FEC_NONE,
        FEC_1_2,
        FEC_2_3,
        FEC_3_4,
        FEC_4_5,
        FEC_5_6,
        FEC_6_7,
        FEC_7_8,
        FEC_8_9,
        FEC_AUTO
    }

    public enum DvbSrcModulation {
        QPSK,
        QAM_16,
        QAM_32,
        QAM_64,
        QAM_128,
        QAM_256,
        QAM_AUTO
    }

    public enum DvbSrcTransmissionMode {
        TRANSMISSION_MODE_2K,
        TRANSMISSION_MODE_8K,
        TRANSMISSION_MODE_AUTO
    }

    public enum DvbSrcBandwidth {
        BANDWIDTH_8_MHZ,
        BANDWIDTH_7_MHZ,
        BANDWIDTH_6_MHZ,
        BANDWIDTH_AUTO
    }

    public enum DvbSrcGuard {
        GUARD_INTERVAL_1_32,
        GUARD_INTERVAL_1_16,
        GUARD_INTERVAL_1_8,
        GUARD_INTERVAL_1_4,
        GUARD_INTERVAL_AUTO
    }

    public enum DvbSrcHierarchy {
        HIERARCHY_NONE,
        HIERARCHY_1,
        HIERARCHY_2,
        HIERARCHY_4,
        HIERARCHY_AUTO
    }

    public enum DvbSrcInversion {
        INVERSION_OFF,
        INVERSION_ON,
        INVERSION_AUTO
    }
    
    /**
     * @bandwith: 0, 6, 7 or 8
     */
    public static DvbSrcBandwidth get_bandwidth_val (uint bandwidth) {
        DvbSrcBandwidth val;
        switch (bandwidth) {
            case 6: val = DvbSrcBandwidth.BANDWIDTH_6_MHZ; break;
            case 7: val = DvbSrcBandwidth.BANDWIDTH_7_MHZ; break;
            case 8: val = DvbSrcBandwidth.BANDWIDTH_8_MHZ; break;
            // 0
            default: val = DvbSrcBandwidth.BANDWIDTH_AUTO; break;
        }
        return val;
    }
    
    /**
     * @hierarchy: 0, 1, 2 or 4.
     * If value doesn't match one of above HIERARCHY_AUTO is returned.
     */
    public static DvbSrcHierarchy get_hierarchy_val (uint hierarchy) {
        DvbSrcHierarchy val;
        switch (hierarchy) {
            case 0: val = DvbSrcHierarchy.HIERARCHY_NONE; break;
            case 1: val = DvbSrcHierarchy.HIERARCHY_1; break;
            case 2: val = DvbSrcHierarchy.HIERARCHY_2; break;
            case 4: val = DvbSrcHierarchy.HIERARCHY_4; break;
            default: val = DvbSrcHierarchy.HIERARCHY_AUTO; break;
        }
        return val;
    }
    
    /**
     * @modulation: QPSK, QAM16, QAM32, QAM64, QAM128 or QAM256.
     * If value doesn't match one of above QAM_AUTO is returned.
     */
    public static DvbSrcModulation get_modulation_val (string constellation) {
        DvbSrcModulation val;
        if (constellation == "QPSK")
            val = DvbSrcModulation.QPSK;
        else if (constellation == "QAM16")
            val = DvbSrcModulation.QAM_16;
        else if (constellation == "QAM32")
            val = DvbSrcModulation.QAM_32;
        else if (constellation == "QAM64")
            val = DvbSrcModulation.QAM_64;
        else if (constellation == "QAM128")
            val = DvbSrcModulation.QAM_128;
        else if (constellation == "QAM256")
            val = DvbSrcModulation.QAM_256;
        else
            val = DvbSrcModulation.QAM_AUTO;
        
        return val;
    }
    
    /**
     * @code_rate_string: "NONE", 1/2", "2/3", "3/4", "4/5", "5/6", "6/7",
     * "7/8" or "8/9".
     * If value doesn't match one of above FEC_AUTO is returned.
     */
    public static DvbSrcCodeRate get_code_rate_val (string code_rate_string) {
        DvbSrcCodeRate val;
        if (code_rate_string == "NONE")
            val = DvbSrcCodeRate.FEC_NONE;
        else if (code_rate_string == "1/2")
            val = DvbSrcCodeRate.FEC_1_2;
        else if (code_rate_string == "2/3")
            val = DvbSrcCodeRate.FEC_2_3;
        else if (code_rate_string == "3/4")
            val = DvbSrcCodeRate.FEC_3_4;
        else if (code_rate_string == "4/5")
            val = DvbSrcCodeRate.FEC_4_5;
        else if (code_rate_string == "5/6")
            val = DvbSrcCodeRate.FEC_5_6;
        else if (code_rate_string == "6/7")
            val = DvbSrcCodeRate.FEC_5_6;
        else if (code_rate_string == "7/8")
            val = DvbSrcCodeRate.FEC_7_8;
        else if (code_rate_string == "8/9")
            val = DvbSrcCodeRate.FEC_8_9;
        else
            val = DvbSrcCodeRate.FEC_AUTO;
        
        return val;
    }
    
    /**
     * @guard: 4, 8, 16 or 32.
     * If value doesn't match one of above GUARD_INTERVAL_AUTO is returned.
     */
    public static DvbSrcGuard get_guard_interval_val (uint guard) {
        DvbSrcGuard val;
        switch (guard) {
            case 4:
            val = DvbSrcGuard.GUARD_INTERVAL_1_4; break;
            case 8:
            val = DvbSrcGuard.GUARD_INTERVAL_1_8; break;
            case 16:
            val = DvbSrcGuard.GUARD_INTERVAL_1_16; break;
            case 32:
            val = DvbSrcGuard.GUARD_INTERVAL_1_32; break;
            default:
            val = DvbSrcGuard.GUARD_INTERVAL_AUTO; break;
        }
        return val;
    }
    
    /**
     * @transmode: "2k" or "8k"
     * If value doesn't match one of above TRANSMISSION_MODE_AUTO is returned.
     */
    public static DvbSrcTransmissionMode get_transmission_mode_val (
        string transmode) {
        DvbSrcTransmissionMode val;
        if (transmode == "2k")
            val = DvbSrcTransmissionMode.TRANSMISSION_MODE_2K;
        else if (transmode == "8k")
            val = DvbSrcTransmissionMode.TRANSMISSION_MODE_8K;
        else
            val = DvbSrcTransmissionMode.TRANSMISSION_MODE_AUTO;
            
        return val;
    }

}
