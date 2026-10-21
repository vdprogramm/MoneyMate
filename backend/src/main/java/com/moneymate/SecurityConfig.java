package com.moneymate;

import com.nimbusds.jose.jwk.source.ImmutableSecret;
import java.nio.charset.StandardCharsets;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
class SecurityConfig {
    @Bean PasswordEncoder passwordEncoder(){return new BCryptPasswordEncoder();}
    @Bean SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http.csrf(csrf->csrf.disable())
          .sessionManagement(s->s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
          .authorizeHttpRequests(a->a.requestMatchers("/api/v1/auth/**","/actuator/health").permitAll()
            .anyRequest().authenticated())
          .oauth2ResourceServer(o->o.jwt(j->{})).build();
    }
    @Bean JwtEncoder jwtEncoder(@Value("${app.jwt-secret}") String secret) {
        byte[] bytes=check(secret);
        return new NimbusJwtEncoder(new ImmutableSecret<>(bytes));
    }
    @Bean JwtDecoder jwtDecoder(@Value("${app.jwt-secret}") String secret) {
        return NimbusJwtDecoder.withSecretKey(new SecretKeySpec(check(secret),"HmacSHA256"))
          .macAlgorithm(MacAlgorithm.HS256).build();
    }
    private static byte[] check(String secret){
        byte[] bytes=secret.getBytes(StandardCharsets.UTF_8);
        if(bytes.length<32)throw new IllegalArgumentException("JWT_SECRET must contain at least 32 UTF-8 bytes");
        return bytes;
    }
}
