package com.moneymate;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity @Table(name="app_users")
class Account {
    @Id UUID id = UUID.randomUUID();
    @Column(name="display_name",nullable=false,length=100) String displayName;
    @Column(nullable=false,unique=true,length=190) String email;
    @Column(name="password_hash",nullable=false) String passwordHash;
    @Column(name="created_at",nullable=false,insertable=false,updatable=false) Instant createdAt;
    protected Account() {}
    Account(String displayName,String email,String passwordHash) {this.displayName=displayName;this.email=email;this.passwordHash=passwordHash;}
}

@Entity @Table(name="wallets")
class Wallet {
    @Id UUID id=UUID.randomUUID();
    @Column(name="owner_id",nullable=false) UUID ownerId;
    @Column(nullable=false,length=80) String name;
    @Column(name="opening_balance",nullable=false,precision=19,scale=2) BigDecimal openingBalance=BigDecimal.ZERO;
    @Column(name="created_at",nullable=false,insertable=false,updatable=false) Instant createdAt;
    protected Wallet() {}
    Wallet(UUID userId,String name,BigDecimal balance){this.ownerId=userId;this.name=name;this.openingBalance=balance;}
}

@Entity @Table(name="money_entries")
class MoneyEntry {
    @Id UUID id=UUID.randomUUID();
    @Column(name="owner_id",nullable=false) UUID ownerId;
    @Column(name="wallet_id",nullable=false) UUID walletId;
    @Column(nullable=false,length=10) String type;
    @Column(nullable=false,length=50) String category;
    @Column(nullable=false,precision=19,scale=2) BigDecimal amount;
    @Column(length=500) String note;
    @Column(name="occurred_on",nullable=false) LocalDate occurredOn;
    @Column(name="created_at",nullable=false,insertable=false,updatable=false) Instant createdAt;
    protected MoneyEntry() {}
    MoneyEntry(UUID ownerId,UUID walletId,String type,String category,BigDecimal amount,String note,LocalDate date) {
        this.ownerId=ownerId;this.walletId=walletId;this.type=type;this.category=category;this.amount=amount;this.note=note;this.occurredOn=date;
    }
}

@Entity @Table(name="budgets",uniqueConstraints={@UniqueConstraint(name="uq_budget_owner_category_month",columnNames={"owner_id","category","month"})})
class Budget {
    @Id UUID id=UUID.randomUUID();
    @Column(name="owner_id",nullable=false) UUID ownerId;
    @Column(nullable=false,length=50) String category;
    @Column(nullable=false,length=7) String month;
    @Column(nullable=false,precision=19,scale=2) BigDecimal amount;
    protected Budget() {}
    Budget(UUID ownerId,String category,String month,BigDecimal amount){this.ownerId=ownerId;this.category=category;this.month=month;this.amount=amount;}
}
