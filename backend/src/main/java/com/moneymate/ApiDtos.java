package com.moneymate;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

final class ApiDtos {
    private ApiDtos() {}
    record RegisterRequest(@NotBlank @Size(min=2,max=100) String displayName,@NotBlank @Email String email,@NotBlank @Size(min=10,max=120) String password) {}
    record LoginRequest(@NotBlank @Email String email,@NotBlank String password) {}
    record AuthResponse(String token,String userId,String email,String displayName) {}
    record WalletRequest(@NotBlank @Size(max=80) String name,@NotNull @DecimalMin("0.00") BigDecimal openingBalance) {}
    record WalletView(UUID id,String name,BigDecimal openingBalance,BigDecimal balance) {}
    record EntryRequest(@NotNull UUID walletId,@NotBlank String type,@NotBlank @Size(max=50) String category,@NotNull @DecimalMin("0.01") BigDecimal amount,@Size(max=500) String note,@NotNull LocalDate occurredOn) {}
    record OfflineEntryRequest(@NotNull UUID clientId,@Valid @NotNull EntryRequest transaction) {}
    record EntryView(UUID id,UUID walletId,String type,String category,BigDecimal amount,String note,LocalDate occurredOn) {}
    record BudgetRequest(@NotBlank @Size(max=50) String category,@NotBlank String month,@NotNull @DecimalMin("0.01") BigDecimal amount) {}
    record BudgetView(UUID id,String category,String month,BigDecimal amount,BigDecimal spent,int usedPercent) {}
}
