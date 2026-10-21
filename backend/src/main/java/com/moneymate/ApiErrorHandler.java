package com.moneymate;

import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

@RestControllerAdvice
class ApiErrorHandler {
    @ExceptionHandler(BadCredentialsException.class)
    ResponseEntity<Map<String,String>> badCredentials(BadCredentialsException e){return ResponseEntity.status(401).body(Map.of("error","Sai email hoặc mật khẩu"));}
    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<Map<String,String>> invalid(MethodArgumentNotValidException e){return ResponseEntity.badRequest().body(Map.of("error",e.getBindingResult().getFieldErrors().stream().findFirst().map(x->x.getField()+": "+x.getDefaultMessage()).orElse("Dữ liệu không hợp lệ")));}
    @ExceptionHandler(ArithmeticException.class)
    ResponseEntity<Map<String,String>> badMoney(ArithmeticException e){return ResponseEntity.badRequest().body(Map.of("error","Số tiền tối đa 2 chữ số thập phân"));}
}
