----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Anton Lind
-- 
-- Create Date: 02/03/2026 10:17:07 AM
-- Design Name: 
-- Module Name: pulse_gen - rtl
-- Project Name: AXI-controlled-pulse-generator
-- Target Devices: 
-- Tool Versions: 
-- Description: Generate programmable pulse trains. Parameters set via AXI-Lite: 
--              Pulse width (high_time_i) 
--              PRF - pulse repetition frequency (pulse_period_i)
--              Burst length (nr_of_pulses)
-- HIGH lasts exactly high_time_reg cycles
-- LOW lasts exactly pulse_period_reg - high_time_reg cycles
-- Pulse count increments once per period

-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pulse_gen is
--  Port ( );
    port(
        clk             : in std_logic;          -- System clock (50 MHz, 20ns cycle)                     
        rst_n           : in std_logic;          -- Synchronous reset (active low)
        start           : in std_logic;          -- Start flag from software to start pulse sequence
        high_time_i     : unsigned(15 downto 0); -- Pulse width (HIGH time). Number of cycles output is HIGH. Ex: 500 × 20 ns = 10 µs
        pulse_period_i  : unsigned(15 downto 0); -- Total pulse period, total cycles per pulse (total period). Ex 1000 × 20 ns = 20 µs
        nr_of_pulses_i  : unsigned(15 downto 0); -- Number of pulses. Ex: 4.
        busy_out        : out std_logic;         -- Busy flag output (busy FSM)
        pulse_out       : out std_logic          -- Digital pulse signal
        );
end pulse_gen;



architecture rtl of pulse_gen is
      
    -- Registers for inputs
    signal high_time_reg        : unsigned(15 downto 0);   
    signal pulse_period_reg     : unsigned(15 downto 0);   
    signal nr_of_pulses_reg     : unsigned(15 downto 0);   
    
    -- Counters
    signal high_time_cnt        : unsigned(15 downto 0);   -- Tracks how many clock cycles have been HIGH in this pulse. Incremetns once per clock
    signal pulse_period_count   : unsigned(15 downto 0);   -- Tracks how many LOW cycles have elapsed since the HIGH phase ended
    signal nr_of_pulses_cnt     : unsigned(15 downto 0);   -- Tracks how many pulses have been completed so far

    -- Output register
    signal pulse_out_reg        : std_logic; 
     
    -- Start 2FF sync signals
    signal start_ff1            : std_logic;
    signal start_ff2            : std_logic;
    
    -- Start edge detect signals
    signal start_prev           : std_logic;  
    signal start_pulse          : std_logic;
    
    -- State decleration
    type t_state is (IDLE, LOAD, PULSE_HIGH, PULSE_LOW, FINISHED);
    signal State : t_state;


    
begin


    -----------------------------------------------------------------
    -- 2FF synchronizer process for start input 
    p_start_2ff_sync : process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                start_ff1 <= '0';
                start_ff2 <= '0';
            else
                start_ff1 <= start;
                start_ff2 <= start_ff1;
            end if;
        end if;
    end process;
    -----------------------------------------------------------------


    -----------------------------------------------------------------
    -- Start edge detect process, registers previous values of "start"
    p_start_edge_detect : process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                start_prev <= '0';
            else
                start_prev <= start_ff2;
            end if;
        end if;
    end process;
    
    -- Detects rising edge of "start"
    start_pulse <= start_ff2 and not start_prev;
    -----------------------------------------------------------------


    -----------------------------------------------------------------
    -- State machine process for the pulse gen logic  
    p_state_machine : process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                -- Output register reset
                pulse_out_reg      <= '0';

                -- Counter reset
                high_time_cnt      <= (others => '0');
                pulse_period_count <= (others => '0');
                nr_of_pulses_cnt   <= (others => '0');
                
                -- Register reset
                high_time_reg      <= (others => '0');
                pulse_period_reg   <= (others => '0');
                nr_of_pulses_reg   <= (others => '0');
                
                -- Go to IDLE state
                State <= IDLE;
            else
                
                --------------------------------------------------------------
                --STATE MACHINE
                --------------------------------------------------------------
                case State is
                
                    ------------------------- IDLE ------------------------------
                    -- Waiting for start from software
                    when IDLE =>
                        pulse_out_reg <= '0';
                        if start_pulse = '1' then 
                            State <= LOAD;
                        end if;
                    --------------------------------------------------------------        
                            
                            
                    ------------------------- LOAD --------------------------------
                    -- Loading software parameters, clear counters, rejecting invalid configs
                    when LOAD =>
                        
                        -- Drive output low
                        pulse_out_reg <= '0';
                        
                       
                        -- Counter reset
                        high_time_cnt <= (others => '0');
                        pulse_period_count   <= (others => '0');
                        nr_of_pulses_cnt <= (others => '0');
                        
                        -- Loading software parameters into registers
                        high_time_reg    <= high_time_i;
                        pulse_period_reg <= pulse_period_i;
                        nr_of_pulses_reg <= nr_of_pulses_i;
                                                
                        -- Rejecting invalid configs
                        if (high_time_reg >= pulse_period_reg or
                            high_time_reg = 0 or
                            pulse_period_reg = 0 or
                            nr_of_pulses_reg = 0) then
                            
                            State <= FINISHED;
                        else
                            State <= PULSE_HIGH;
                        end if;                                                        
                    --------------------------------------------------------------
                        
                        
                    ---------------------- PULSE HIGH ----------------------------   
                    -- Output high, count pulse high width            
                    when PULSE_HIGH =>
                        
                        -- Drive output high
                        pulse_out_reg <= '1';

                        if high_time_cnt = high_time_reg-1 then
                            -- High time counter reached high time input
                            high_time_cnt <= (others => '0');
                            State <= PULSE_LOW;
                        else
                            high_time_cnt <= high_time_cnt + 1;
                        end if;
                    --------------------------------------------------------------
                    
                        
                    ---------------------- PULSE LOW -----------------------------  
                    -- Output low, count remainder of pulse width    
                    when PULSE_LOW =>
                        -- Updating, busy and drive low output  
                        pulse_out_reg <= '0';
                        
                        -- HIGH cycles = high_time_reg --> LOW cycles = pulse_period_reg - high_time_reg. Counter starts at 0, so -1 
                        if pulse_period_count = (pulse_period_reg - high_time_reg - 1) then
                            -- Pulse completed 
                            pulse_period_count <= (others => '0');
                            nr_of_pulses_cnt <= nr_of_pulses_cnt + 1;
                            if nr_of_pulses_cnt = nr_of_pulses_reg - 1 then
                                -- Needed number of pulses has been reached
                                State <= FINISHED;
                            else
                                State <= PULSE_HIGH;
                            end if;
                        else
                            pulse_period_count <= pulse_period_count + 1;
                        end if;
                    --------------------------------------------------------------      
                    
                            
                    ---------------------- FINISHED ----------------------------------          
                    -- Pulses/burst finished, wait for clear
                    when FINISHED =>
                        -- Drive output low
                        pulse_out_reg <= '0';
                        
                        -- Handshake to confirm that start flag is 0 and can go back to IDLE state
                        if start_ff2 = '0' then
                            State <= IDLE;
                        end if;
                    --------------------------------------------------------------
                end case;
            end if;
        end if;
    end process;
    
    busy_out <= '1' when State /= IDLE else '0'; 
    pulse_out <= pulse_out_reg;
    
end rtl;
