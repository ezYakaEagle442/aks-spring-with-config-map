package com.example.hellospring;

import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestMapping;

import java.net.*;
import java.io.BufferedReader;
import java.io.InputStreamReader;

// java -jar target\hellospring-0.0.1-SNAPSHOT.jar --spring.cloud.config.enabled=false --spring.cloud.config.import-check.enabled=false
@RestController
public class IpController {

    @RequestMapping("/ip")
    public String whatismyip() {

        String systemipaddress = "";
        try {
            URL url_name = new URL("http://whatismyip.akamai.com");

            BufferedReader sc = new BufferedReader(new InputStreamReader(url_name.openStream()));

            // reads system IPAddress
            systemipaddress = sc.readLine().trim();
        }
        catch (Exception e) {
            systemipaddress = "Cannot Execute Properly";
        }
        // Print IP address
        System.out.println("Public IP Address: " + systemipaddress + "\n");
    
        return "Public IP Address: " + systemipaddress + "\n";
    }

}