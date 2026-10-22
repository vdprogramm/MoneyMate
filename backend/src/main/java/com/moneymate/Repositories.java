package com.moneymate;

import java.util.*;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.math.BigDecimal;
import java.time.LocalDate;

interface AccountRepository extends JpaRepository<Account,UUID> {
    Optional<Account> findByEmail(String email);
    boolean existsByEmail(String email);
}
interface WalletRepository extends JpaRepository<Wallet,UUID> {
    List<Wallet> findByOwnerIdOrderByCreatedAtAsc(UUID ownerId);
    Optional<Wallet> findByIdAndOwnerId(UUID id,UUID ownerId);
}
interface MoneyEntryRepository extends JpaRepository<MoneyEntry,UUID> {
    List<MoneyEntry> findByOwnerIdOrderByOccurredOnDescCreatedAtDesc(UUID ownerId);
    Optional<MoneyEntry> findByIdAndOwnerId(UUID id,UUID ownerId);
    // Atomic idempotent insert: the client's UUID is the actual transaction PK.
    @Modifying
    @Query(value = """
        INSERT INTO money_entries (id,owner_id,wallet_id,type,category,amount,note,occurred_on)
        VALUES (:id,:ownerId,:walletId,:type,:category,:amount,:note,:occurredOn)
        ON CONFLICT (id) DO NOTHING
        """, nativeQuery = true)
    int insertOfflineOnce(@Param("id") UUID id,
                          @Param("ownerId") UUID ownerId,
                          @Param("walletId") UUID walletId,
                          @Param("type") String type,
                          @Param("category") String category,
                          @Param("amount") BigDecimal amount,
                          @Param("note") String note,
                          @Param("occurredOn") LocalDate occurredOn);
}
interface BudgetRepository extends JpaRepository<Budget,UUID> {
    List<Budget> findByOwnerIdAndMonth(UUID ownerId,String month);
    Optional<Budget> findByOwnerIdAndCategoryAndMonth(UUID ownerId,String category,String month);
    Optional<Budget> findByIdAndOwnerId(UUID id,UUID ownerId);
}
