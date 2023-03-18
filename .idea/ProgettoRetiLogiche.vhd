--------------------------------------------------------------------------------
-- Juan David Liut Aymar
-- Codice Persona: 10607787

-- Module Name: project_reti_logiche - Behavioral
-- Project Name: Prova Finale - Progetto Reti Logiche 2020-2021

----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.math_real.all;
use IEEE.NUMERIC_STD.ALL;

entity project_reti_logiche is
    port (
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_start : in std_logic;
    i_data : in std_logic_vector(7 downto 0);
    o_address : out std_logic_vector(15 downto 0);
    o_done : out std_logic;
    o_en : out std_logic;
    o_we : out std_logic;
    o_data : out std_logic_vector (7 downto 0)
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
    -- il componente � stato pensato come una macchina FSM composta da 8 stati
    type states is (START_STATE,READ_DIM, WAIT_DIM, FIND_MAX_MIN, WAIT_STATE, CONVERSION, WAIT_END, WRITE_STATE);
    signal current_state: states:= start_state; --comincio sempre dallo start_state
    signal dim: integer;  --dimensione dell'immagine
    signal count: integer := 0;  --contatore per calcolo della dimensione dell'immagine
    -- max e min
    signal MAX_PIXEL_VALUE: unsigned(7 downto 0);
    signal MIN_PIXEL_VALUE: unsigned(7 downto 0);
    signal number_address : integer;  -- l'indirizzo su cui andr� a lavorare in lettura
    signal start: std_logic_vector(15 downto 0);  --indirizzo in cui iniziano i byte delle immagini

--funzione per il floor_log2    
    function shift_lvl(DELTA_VALUE: integer) 
        return integer is 
        variable X : integer;
    begin
    -- a seconda del delta_value che ho, avr� un floor
    -- la scelta del Floor avviene tramite uno switch
        case DELTA_VALUE is
            when 0 => X:= 0 ;
            when 1 to 2 => X:= 1;
            when 3 to 6 => X:= 2;
            when 7 to 14 => X:= 3;
            when 15 to 30 => X:= 4;
            when 31 to 62 => X:= 5;
            when 63 to 126 => X:= 6;
            when 127 to 254 => X:= 7;
            when 255 => X:= 8;
            when others => X:=0;
        end case;
     -- calcolo Shift_Level : (8 - Floor)
       X := 8 - X;
       return X;
    end shift_lvl;

    
begin
-- le azioni eseguite dal seguente processo sono:
--  - lettura dimensione immagine
--  - lettura dei pixel per trovare max e min
--  - conversione e scrittura
process (i_clk, i_rst, i_start)
    --le seguenti variabili servono per risolvere le equazioni per equalizzare l'istogramma
    --delle immagini date (i nomi sono quelli usati nella specifica del progetto)
    variable CURRENT_PIXEL_VALUE: integer;
    variable SHIFT_LEVEL: integer;
    variable TEMP_PIXEL: integer;
    variable NEW_PIXEL_VALUE: unsigned(7 downto 0);
    --flag che mi dice se i valori di max(M) e di min(m) sono stati trovati
    variable M_m: boolean:=false;
    
    begin
    --se i_clk=1 allora controllo i_rst
        if rising_edge(i_clk)then
        --inizializzo gli strumenti che mi serviranno 
        o_data<= "00000000"; --inizializzo il segnale di uscita alla memoria
        o_done<='0'; -- o_done � tenuto basso finch� la conevrsione dell'immagine non � terminata
        o_en<='0'; -- o_en � tenuto basso cos� non ho accesso alla memoria
        o_we<='0';
        
            if (i_rst='1') then
                current_state <= start_state;
            else
                --altrimenti comicincio
    
        --in base a quale stato si trova la macchina, questa esegue una determinata azione
        case current_state is
            
            --stato iniziale
            when START_STATE => dim <= 1; 
                                number_address <= 0; --parto dal primo indirizzo: l'indirzzo 0
                                count <= 0 ; --contatore inizializzato
                                MAX_PIXEL_VALUE<= "00000000"; --Max=0
                                MIN_PIXEL_VALUE<= "11111111"; --min=255
                                M_m:=false; --flag settato a "false" perch� i valori M e m non sono stati ancora trovati
                                if (i_start='1') then
                                    o_done<='0'; --il processo di conversione ha inizio: tengo basso o_done
                                    current_state <= READ_DIM; 
                                end if;
            
            
            --stato in cui si legge la dimensione dell'immagine                    
            when READ_DIM => if count=0 then   -- se non ha gi� letto il numero di colonne, allora lo leggo
                                 o_en<='1'; -- richiedo la lettura dalla memoria di o_address
                                 o_address <= std_logic_vector(TO_UNSIGNED(number_address,16)); --indirizzo 0
                                 count <= count +1;  -- conto un indirizzo letto                           
                                 number_address <= number_address +1; --passo all'indirizzo successivo,l'1 
                                 current_state <= WAIT_DIM; 
                             
                             elsif count=1 then  -- se non ha gi� letto il numero di righe, allora lo leggo
                                 o_en<='1';
                                 o_address <= std_logic_vector(TO_UNSIGNED(number_address,16)); 
                                 --ora uso i_data 
                                 dim <= dim * TO_INTEGER(unsigned(i_data)); --i_data di indirizzo 0
                                 count <= count +1;
                                 number_address <= number_address +1; --mi sposto all'indirizzo dopo,il 2
                                 current_state <= WAIT_DIM;
                             
                             else -- se ho gi� letto le dimensioni delle immagini
                                 dim <= dim * TO_INTEGER(unsigned(i_data)); --i_data di inidirizzo 1
                                 -- se l'immagine � vuota, finisco il processo
                                 if (dim = 0) then
                                    o_done<='1';
                                    current_state <= WAIT_END;
                                 -- altrimenti, l'immagine ha dei pixel e passo all'indirizzo 3
                                 else
                                    start <= std_logic_vector(TO_UNSIGNED(number_address,16));
                                    o_en<='1';
                                    o_address <= std_logic_vector(TO_UNSIGNED(number_address,16));
                                    count <= 0;
                                    current_state <= WAIT_STATE; --vado a leggere max e min
                                 end if;
                              end if;   

          -- stato in cui leggo il contenuto dell'indirizzo richiesto                     
          when WAIT_DIM => current_state <= READ_DIM; 
          
          -- stato in cui gestisco tre situazioni diverse, basandomi sul flag M_m
          when WAIT_STATE => if M_m then
                                   -- se ho letto e convertito tutti i pixel (dim = count) allora termino
                                   if dim = count then
                                        o_done<='1';
                                        current_state <= WAIT_END;
                                    else
                                    -- altrimenti contnuo con la elaborazione
                                        current_state <= CONVERSION;
                                   end if; 
                             else
                             -- se non sono stati ancora trovati max e min, continuo con la ricerca
                                   number_address<= number_address +1;
                                   current_state <= FIND_MAX_MIN;
                             end if;                          
          
          -- stato in cui cerco il valore Max e min nei pixel dell'immagine
          --letto il byte confronto i pixel per trovare il max e min
          when FIND_MAX_MIN =>  if (unsigned(i_data)>unsigned(MAX_PIXEL_VALUE))then
                                    MAX_PIXEL_VALUE <= unsigned(i_data);
                                end if;
                                if (unsigned(i_data)<unsigned(MIN_PIXEL_VALUE))then
                                    MIN_PIXEL_VALUE <= unsigned(i_data);
                                end if;
                                count <= count +1; 
                                --se arrivo alla fine dell'immagine, passo ad elaborare ogni singolo pixel
                                if (dim = count+1)then
                                    count <= 0;
                                    number_address <= TO_INTEGER(unsigned(start));
                                    o_en<='1'; --devo leggere il pixel
                                    o_address<=start;
                                    M_m := true;
                                    current_state <= WAIT_STATE;
                                -- altrimenti continuo con la lettura dei pixel
                                else 
                                    o_en <='1'; --richiedo la lettura del pizel all'indirizzo o_address
                                    o_address <=std_logic_vector(TO_UNSIGNED(number_address,16));
                                    --una volta tornato dallo stato WAIT_STATE, il dato sar� pronto
                                    current_state <= WAIT_STATE;
                                end if;
                                
           --stato in cui processo un pixel alla volta                     
           when CONVERSION => --considero un pixel 
                                CURRENT_PIXEL_VALUE := TO_INTEGER(unsigned(i_data));
                                -- 1) ricavo SHIFT_LEVEL (shift_lvl � una funzione che mi ricava quest'ultimo)
                                SHIFT_LEVEL := integer(shift_lvl(TO_INTEGER(MAX_PIXEL_VALUE - MIN_PIXEL_VALUE)));
                                --2) ricavo TEMP_PIXEL
                                -- NB: do pi� spazio per lo shift altrimenti i numeri pi� grandi di 255 non verranno mai considerati
                                TEMP_PIXEL := TO_INTEGER(resize(unsigned(CURRENT_PIXEL_VALUE - MIN_PIXEL_VALUE),16) sll SHIFT_LEVEL);
                                --3) ricavo NEW_PIXEL_VALUE
                                if (TEMP_PIXEL<255 ) then
                                    o_data <= std_logic_vector(TO_UNSIGNED(TEMP_PIXEL,8)); -- NEW_PIXEL_VALUE = TEMP_PIXEL                          
                                else
                                    o_data <= "11111111"; -- NEW_PIXEL_VALUE = 255
                                end if;
                                -- punto all'indirizzo in cui devo scrivere
                                o_address<=std_logic_vector(TO_UNSIGNED((number_address+dim),16));
                                o_en<= '1'; 
                                o_we<= '1';  --autorizzo la scrittura in memoria 
                                count<= count+1;
                                number_address<= number_address +1;
                                current_state <= WRITE_STATE;
             
             --stato in cui viene scritto in memoria il nuovo pixel e viene richiesta la lettura di un indirizzo                
             when WRITE_STATE   => o_en<='1';
                                   o_we<='0';
                                   o_address<=std_logic_vector(TO_UNSIGNED(number_address,16));
                                   current_state <= WAIT_STATE;      
                                           
             --stato in cui si setta o_done alto (perch� l'elaborazione dell'immagine � terminata) e
             --si attende che il segnale i_start venga portato basso                
             when WAIT_END => if i_start='0' then
                              --se il tempo di computazione � gi� finito, torno allo stato iniziale e o_done viene settato basso cos� 
                              --l'elemento � pronto per una nuova elaborazione
                               current_state <= start_state;
                           else
                               --il segnale o_done viene mantenuto alto finch� i_start non torna basso
                               current_state <= WAIT_END;
                               o_done<='1';
                           end if;
            
        end case;    
        end if;
        end if;
    end process;


end Behavioral;
