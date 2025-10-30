package com.example.demo;

import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;

class HelloControllerTest {
    @Test
    void helloReturnsGreeting() {
        HelloController c = new HelloController();
        assertThat(c.hello()).isEqualTo("Hello from Java 17 app!");
    }
}
