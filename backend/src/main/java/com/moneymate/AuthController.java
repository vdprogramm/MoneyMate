package com.moneymate;

import static com.moneymate.ApiDtos.*;
import jakarta.validation.Valid;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Locale;
import org.springframework.http.*;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController @RequestMapping("/api/v1/auth")
class AuthController {
    private final AccountRepository users;private final WalletRepository wallets;private final PasswordEncoder passwords;private final JwtEncoder encoder;
    AuthController(AccountRepository u,WalletRepository w,PasswordEncoder p,JwtEncoder j){users=u;wallets=w;passwords=p;encoder=j;}
    @PostMapping("/register") @Transactional
    AuthResponse register(@Valid @RequestBody RegisterRequest req) {
        String email=req.email().strip().toLowerCase(Locale.ROOT);
        if(users.existsByEmail(email))throw new ResponseStatusException(HttpStatus.CONFLICT,"Email đã được sử dụng");
        Account u=users.save(new Account(req.displayName().strip(),email,passwords.encode(req.password())));
        wallets.save(new Wallet(u.id,"Tiền mặt",java.math.BigDecimal.ZERO));
        return token(u);
    }
    @PostMapping("/login")
    AuthResponse login(@Valid @RequestBody LoginRequest req) {
        Account u=users.findByEmail(req.email().strip().toLowerCase(Locale.ROOT))
          .orElseThrow(()->new BadCredentialsException("Sai email hoặc mật khẩu"));
        if(!passwords.matches(req.password(),u.passwordHash))throw new BadCredentialsException("Sai email hoặc mật khẩu");
        return token(u);
    }
    private AuthResponse token(Account u){
        Instant now=Instant.now();
        JwtClaimsSet claims=JwtClaimsSet.builder().issuer("moneymate-api").issuedAt(now)
          .expiresAt(now.plus(7,ChronoUnit.DAYS)).subject(u.id.toString()).build();
        JwsHeader header=JwsHeader.with(MacAlgorithm.HS256).build();
        String jwt=encoder.encode(JwtEncoderParameters.from(header,claims)).getTokenValue();
        return new AuthResponse(jwt,u.id.toString(),u.email,u.displayName);
    }
}
