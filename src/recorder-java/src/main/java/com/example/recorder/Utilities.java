package com.example.recorder;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import java.lang.management.GarbageCollectorMXBean;
import java.lang.management.ManagementFactory;
import java.util.ArrayList;
import java.util.List;

import org.springframework.stereotype.Service;

/**
 * Service layer is where all the business logic lies
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class Utilities {
    private int lastGcTime = -1;

    public int getGarbageCollectorDeltaTime (){
        int gcTime = 0;
        for (GarbageCollectorMXBean gcBean : ManagementFactory.getGarbageCollectorMXBeans()) {
            gcTime += gcBean.getCollectionTime();
        }
        int gcDelta = 0;
        if (lastGcTime != -1)
            gcDelta = gcTime - lastGcTime;
        lastGcTime = gcTime;
        return gcDelta;
    }

    public static void thrashGarbageCollector() {
        List<Object> garbageList = new ArrayList<>();
        for (int i = 0; i < 100000; i++) {
            // Each iteration creates a new, small object
            garbageList.add(new byte[1024]); // Allocate 1KB byte array
        }
        System.gc();
    }
}
