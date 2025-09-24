package com.example.recorder;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

/**
 * Repository is an interface that provides access to data in a database
 */
public interface TradeRepo extends JpaRepository<Trade, String> {
        @Modifying
        @Query(value = "CREATE EXTENSION pg_stat_statements;", nativeQuery = true)
        void enablePGStatStatements();
}