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

    @Test void offlineTransactionReplayDoesNotCreateSecondEntry(){
        UUID userId=UUID.randomUUID(),walletId=UUID.randomUUID(),clientId=UUID.randomUUID();
        when(authentication.getName()).thenReturn(userId.toString());
        when(wallets.findByIdAndOwnerId(walletId,userId))
            .thenReturn(Optional.of(new Wallet(userId,"Ví",BigDecimal.ZERO)));
        var body=new ApiDtos.EntryRequest(walletId,"EXPENSE","Ăn uống",
            new BigDecimal("45000"),"Offline",LocalDate.now());
        var entry=new MoneyEntry(userId,walletId,"EXPENSE","Ăn uống",
            new BigDecimal("45000.00"),"Offline",LocalDate.now());
        entry.id=clientId;
        when(entries.findByIdAndOwnerId(clientId,userId)).thenReturn(Optional.of(entry));
        var request=new ApiDtos.OfflineEntryRequest(clientId,body);
        var first=controller.syncOfflineEntry(authentication,request);
        var second=controller.syncOfflineEntry(authentication,request);
        assertEquals(first.id(),second.id());
        verify(entries,times(2)).insertOfflineOnce(eq(clientId),eq(userId),
            eq(walletId),eq("EXPENSE"),eq("Ăn uống"),eq(new BigDecimal("45000.00")),
            eq("Offline"),eq(LocalDate.now()));
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
