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

}
