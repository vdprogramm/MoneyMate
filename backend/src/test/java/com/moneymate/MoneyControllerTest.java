package com.moneymate;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.Authentication;
import org.springframework.web.server.ResponseStatusException;

@ExtendWith(MockitoExtension.class)
class MoneyControllerTest {
    @Mock WalletRepository wallets;
    @Mock MoneyEntryRepository entries;
    @Mock BudgetRepository budgets;
    @Mock AccountRepository users;
    @Mock Authentication authentication;
    @InjectMocks MoneyController controller;

    @Test void canCreateExpenseForOwnWallet(){
        UUID userId=UUID.randomUUID(), walletId=UUID.randomUUID();
        when(authentication.getName()).thenReturn(userId.toString());
        when(wallets.findByIdAndOwnerId(walletId,userId)).thenReturn(Optional.of(new Wallet(userId,"Ví",BigDecimal.ZERO)));
        when(entries.save(any(MoneyEntry.class))).thenAnswer(call->call.getArgument(0));
        var result=controller.addEntry(authentication,new ApiDtos.EntryRequest(walletId,"expense","Ăn uống",new BigDecimal("125000"),"Bữa trưa",LocalDate.now()));
        assertEquals("EXPENSE",result.type());
        assertEquals(new BigDecimal("125000.00"),result.amount());
        verify(wallets).findByIdAndOwnerId(walletId,userId);
    }

    @Test void cannotEditOtherUsersTransaction(){
        UUID intruder=UUID.randomUUID(), entryId=UUID.randomUUID();
        when(authentication.getName()).thenReturn(intruder.toString());
        when(entries.findByIdAndOwnerId(entryId,intruder)).thenReturn(Optional.empty());
        assertThrows(ResponseStatusException.class,()->controller.updateEntry(authentication,entryId,
            new ApiDtos.EntryRequest(UUID.randomUUID(),"EXPENSE","Khác",BigDecimal.ONE,"",LocalDate.now())));
        verify(entries,never()).save(any(MoneyEntry.class));
    }
}
