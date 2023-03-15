package com.example.hellospring;

import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestMapping;
//import org.slf4j.Logger;
//import org.slf4j.LoggerFactory;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.apache.logging.log4j.core.LoggerContext;

@RestController
public class HelloController {

    @RequestMapping("/")
    public String index() {
        LoggerContext context = (LoggerContext) LogManager.getContext(false);
        // context.setConfigLocation(new URI("/etc/config/log4j2.xml"));
        Logger logger = LogManager.getLogger(HelloController.class);
        // Logger logger = LoggerFactory.getLogger(HelloController.class);

        logger.trace("+++ TRACE Message");
        logger.debug("+++ DEBUG Message");
        logger.info("+++ INFO Message");
        logger.warn("+++ WARN Message");
        logger.error("+++ ERROR Message");   
        return "Greetings from Azure !  Check out the Logs to see the output...";
    }

}