package com.moneymate;

import static com.moneymate.ApiDtos.*;
import jakarta.validation.Valid;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.*;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController @RequestMapping("/api/v1")
class MoneyController {
    private final WalletRepository wallets;
    private final MoneyEntryRepository entries;
    private final BudgetRepository budgets;
    private final AccountRepository users;
    MoneyController(WalletRepository w,MoneyEntryRepository e,BudgetRepository b,AccountRepository u){wallets=w;entries=e;budgets=b;users=u;}
    private UUID owner(Authentication a){return UUID.fromString(a.getName());}
    private RuntimeException notFound(){return new ResponseStatusException(HttpStatus.NOT_FOUND,"Không tìm thấy dữ liệu");}
    private static BigDecimal money(BigDecimal n){return n.setScale(2,RoundingMode.UNNECESSARY);}
    private String checkType(String type){
        String t=type.toUpperCase(Locale.ROOT);
        if(!t.equals("INCOME")&&!t.equals("EXPENSE"))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"type phải là INCOME hoặc EXPENSE");
        return t;
    }
    private String month(String month){
        try {return YearMonth.parse(month).toString();}
        catch(Exception e){throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"month phải có định dạng YYYY-MM");}
    }
    private void checkWallet(UUID id,UUID owner){wallets.findByIdAndOwnerId(id,owner).orElseThrow(this::notFound);}
    private EntryView view(MoneyEntry e){return new EntryView(e.id,e.walletId,e.type,e.category,e.amount,e.note,e.occurredOn);}
    private BigDecimal signed(MoneyEntry e){return e.type.equals("INCOME")?e.amount:e.amount.negate();}
    @GetMapping("/users/me")
    Map<String,Object> me(Authentication a){Account u=users.findById(owner(a)).orElseThrow(this::notFound);return Map.of("id",u.id,"displayName",u.displayName,"email",u.email);}

    @GetMapping("/wallets")
    List<WalletView> listWallets(Authentication a){
        UUID id=owner(a);
        Map<UUID,BigDecimal> changes=new HashMap<>();
        for(MoneyEntry e:entries.findByOwnerIdOrderByOccurredOnDescCreatedAtDesc(id))changes.merge(e.walletId,signed(e),BigDecimal::add);
        return wallets.findByOwnerIdOrderByCreatedAtAsc(id).stream().map(w->new WalletView(w.id,w.name,w.openingBalance,w.openingBalance.add(changes.getOrDefault(w.id,BigDecimal.ZERO)))).toList();
    }
    @PostMapping("/wallets") @ResponseStatus(HttpStatus.CREATED) @Transactional
    WalletView addWallet(Authentication a,@Valid @RequestBody WalletRequest request){
        Wallet w=wallets.save(new Wallet(owner(a),request.name().strip(),money(request.openingBalance())));
        return new WalletView(w.id,w.name,w.openingBalance,w.openingBalance);
    }

    @GetMapping("/transactions")
    List<EntryView> listEntries(Authentication a){return entries.findByOwnerIdOrderByOccurredOnDescCreatedAtDesc(owner(a)).stream().map(this::view).toList();}
    @PostMapping("/transactions") @ResponseStatus(HttpStatus.CREATED) @Transactional
    EntryView addEntry(Authentication a,@Valid @RequestBody EntryRequest request){
        UUID id=owner(a);checkWallet(request.walletId(),id);
        MoneyEntry e=new MoneyEntry(id,request.walletId(),checkType(request.type()),request.category().strip(),money(request.amount()),request.note(),request.occurredOn());
        return view(entries.save(e));
    }
    @PutMapping("/transactions/{id}") @Transactional
    EntryView updateEntry(Authentication a,@PathVariable UUID id,@Valid @RequestBody EntryRequest request){
        UUID uid=owner(a);MoneyEntry e=entries.findByIdAndOwnerId(id,uid).orElseThrow(this::notFound);
        checkWallet(request.walletId(),uid);
        e.walletId=request.walletId();e.type=checkType(request.type());e.category=request.category().strip();e.amount=money(request.amount());e.note=request.note();e.occurredOn=request.occurredOn();
        return view(entries.save(e));
    }
    @DeleteMapping("/transactions/{id}") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional
    void deleteEntry(Authentication a,@PathVariable UUID id){entries.delete(entries.findByIdAndOwnerId(id,owner(a)).orElseThrow(this::notFound));}

    @GetMapping("/categories")
    Map<String,List<String>> categories(){return Map.of("expense",List.of("Ăn uống","Mua sắm","Di chuyển","Nhà ở","Hóa đơn","Giải trí","Sức khỏe","Giáo dục","Khác"),"income",List.of("Lương","Thưởng","Đầu tư","Quà tặng","Khác"));}

    @GetMapping("/budgets")
    List<BudgetView> listBudgets(Authentication a,@RequestParam String month){
        UUID uid=owner(a);String m=month(month);
        Map<String,BigDecimal> sums=categoryExpenses(uid,YearMonth.parse(m));
        return budgets.findByOwnerIdAndMonth(uid,m).stream().map(b->budgetView(b,sums)).toList();
    }
    private BudgetView budgetView(Budget b,Map<String,BigDecimal> sums){
        BigDecimal spent=sums.getOrDefault(b.category,BigDecimal.ZERO);
        int percentage=spent.multiply(BigDecimal.valueOf(100)).divide(b.amount,0,RoundingMode.DOWN).intValue();
        return new BudgetView(b.id,b.category,b.month,b.amount,spent,percentage);
    }
    @PostMapping("/budgets") @Transactional
    BudgetView upsertBudget(Authentication a,@Valid @RequestBody BudgetRequest request){
        UUID uid=owner(a);String m=month(request.month());BigDecimal amount=money(request.amount());String category=request.category().strip();
        Budget b=budgets.findByOwnerIdAndCategoryAndMonth(uid,category,m).orElseGet(()->new Budget(uid,category,m,amount));
        b.amount=amount;Budget saved=budgets.save(b);
        return budgetView(saved,categoryExpenses(uid,YearMonth.parse(m)));
    }
    @DeleteMapping("/budgets/{id}") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional
    void deleteBudget(Authentication a,@PathVariable UUID id){budgets.delete(budgets.findByIdAndOwnerId(id,owner(a)).orElseThrow(this::notFound));}

    private Map<String,BigDecimal> categoryExpenses(UUID uid,YearMonth month){
        return entries.findByOwnerIdOrderByOccurredOnDescCreatedAtDesc(uid).stream()
          .filter(e->e.type.equals("EXPENSE")&&YearMonth.from(e.occurredOn).equals(month))
          .collect(Collectors.toMap(e->e.category,e->e.amount,BigDecimal::add));
    }
    @GetMapping("/reports/summary")
    Map<String,Object> summary(Authentication a,@RequestParam String month){
        UUID uid=owner(a);YearMonth ym=YearMonth.parse(month(month));
        List<MoneyEntry> all=entries.findByOwnerIdOrderByOccurredOnDescCreatedAtDesc(uid);
        BigDecimal income=BigDecimal.ZERO,expense=BigDecimal.ZERO,net=BigDecimal.ZERO;
        for(MoneyEntry e:all){net=net.add(signed(e));if(YearMonth.from(e.occurredOn).equals(ym)){
           if(e.type.equals("INCOME"))income=income.add(e.amount);else expense=expense.add(e.amount);
        }}
        BigDecimal opening=wallets.findByOwnerIdOrderByCreatedAtAsc(uid).stream().map(w->w.openingBalance).reduce(BigDecimal.ZERO,BigDecimal::add);
        Map<String,Object> result=new LinkedHashMap<>();
        result.put("totalBalance",opening.add(net));result.put("income",income);result.put("expense",expense);
        result.put("byCategory",categoryExpenses(uid,ym));result.put("recentTransactions",all.stream().limit(5).map(this::view).toList());
        return result;
    }
}
