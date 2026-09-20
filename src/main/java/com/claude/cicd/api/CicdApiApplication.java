package com.claude.cicd.api;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication(scanBasePackages = {"com.claude.cicd.api", "com.claude.cicd.payment"})
public class CicdApiApplication {

	public static void main(String[] args) {
		SpringApplication.run(CicdApiApplication.class, args);
	}

}
