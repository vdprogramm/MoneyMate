package com.moneymate;

import java.util.*;
import org.springframework.data.jpa.repository.JpaRepository;

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
}
interface BudgetRepository extends JpaRepository<Budget,UUID> {
    List<Budget> findByOwnerIdAndMonth(UUID ownerId,String month);
    Optional<Budget> findByOwnerIdAndCategoryAndMonth(UUID ownerId,String category,String month);
    Optional<Budget> findByIdAndOwnerId(UUID id,UUID ownerId);
}
