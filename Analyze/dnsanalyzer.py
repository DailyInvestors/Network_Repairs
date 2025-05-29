from scapy.all import sniff, DNS, DNSQR, DNSRR, IP, UDP, TCP
import logging
import time

# --- Configuration ---
LOG_FILE = 'dns_traffic_analysis.log'
# Interface to sniff on. Leave as None to let Scapy try to find one.
# Examples: 'eth0', 'wlan0', 'en0', 'Wi-Fi'
INTERFACE = None
# Number of packets to capture. Set to 0 for infinite capture (Ctrl+C to stop).
COUNT = 100
# Timeout for sniffing. Set to 0 for no timeout (Ctrl+C to stop).
TIMEOUT = 30

# --- Logging Setup ---
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    filename=LOG_FILE,
    filemode='a' # Append to the log file
)
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
console_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
logging.getLogger().addHandler(console_handler)

def dns_parser(packet):
    """
    Parses a DNS packet and logs relevant information.
    """
    if IP in packet and (UDP in packet or TCP in packet) and DNS in packet:
        src_ip = packet[IP].src
        dst_ip = packet[IP].dst
        protocol = "UDP" if UDP in packet else "TCP"
        query_type = "QUERY" if packet[DNS].qr == 0 else "RESPONSE"

        try:
            if query_type == "QUERY" and packet[DNS].qd:
                # DNS Query
                query_name = packet[DNS].qd.qname.decode('utf-8').rstrip('.')
                query_type_str = packet[DNS].qd.qtype
                # Map qtype to human-readable format if possible (Scapy often does this automatically)
                # You can extend this mapping if needed
                qtype_map = {1: 'A', 2: 'NS', 5: 'CNAME', 6: 'SOA', 12: 'PTR', 15: 'MX', 16: 'TXT', 28: 'AAAA', 255: 'ANY'}
                qtype_readable = qtype_map.get(query_type_str, str(query_type_str))

                log_message = (
                    f"[{protocol} DNS QUERY] "
                    f"Src: {src_ip}, Dst: {dst_ip}, "
                    f"Domain: {query_name}, Type: {qtype_readable}"
                )
                logging.info(log_message)

            elif query_type == "RESPONSE" and packet[DNS].an:
                # DNS Response (with answers)
                for i in range(packet[DNS].ancount):
                    ans = packet[DNS].an[i]
                    ans_name = ans.rrname.decode('utf-8').rstrip('.')
                    ans_type = ans.type
                    ans_data = ""

                    # Attempt to get readable answer data based on type
                    if ans.type == 1: # A record
                        ans_data = ans.rdata
                    elif ans.type == 28: # AAAA record
                        ans_data = ans.rdata
                    elif ans.type == 5: # CNAME record
                        ans_data = ans.rdata.decode('utf-8').rstrip('.')
                    elif ans.type == 2: # NS record
                        ans_data = ans.rdata.decode('utf-8').rstrip('.')
                    elif ans.type == 12: # PTR record
                        ans_data = ans.rdata.decode('utf-8').rstrip('.')
                    elif ans.type == 15: # MX record
                        # MX records have a preference and a mail exchanger
                        ans_data = f"Preference:{ans.preference} MailExchanger:{ans.exchange.decode('utf-8').rstrip('.')}"
                    else:
                        ans_data = str(ans.rdata) # Fallback for other types

                    atype_map = {1: 'A', 2: 'NS', 5: 'CNAME', 6: 'SOA', 12: 'PTR', 15: 'MX', 16: 'TXT', 28: 'AAAA'}
                    atype_readable = atype_map.get(ans_type, str(ans_type))

                    log_message = (
                        f"[{protocol} DNS RESPONSE] "
                        f"Src: {src_ip}, Dst: {dst_ip}, "
                        f"Domain: {ans_name}, Type: {atype_readable}, Answer: {ans_data}"
                    )
                    logging.info(log_message)
            elif query_type == "RESPONSE" and packet[DNS].rcode != 0:
                # DNS Response with error (e.g., NXDOMAIN - no such domain)
                rcode_map = {
                    0: "NoError", 1: "FormErr", 2: "ServFail", 3: "NXDomain",
                    4: "NotImp", 5: "Refused", 6: "YXDomain", 7: "YXRRSet",
                    8: "NXRRSet", 9: "NotAuth", 10: "NotZone"
                }
                rcode_readable = rcode_map.get(packet[DNS].rcode, f"Unknown Error {packet[DNS].rcode}")
                query_name = "N/A"
                if packet[DNS].qd:
                    query_name = packet[DNS].qd.qname.decode('utf-8').rstrip('.')
                log_message = (
                    f"[{protocol} DNS ERROR RESPONSE] "
                    f"Src: {src_ip}, Dst: {dst_ip}, "
                    f"Query: {query_name}, Rcode: {rcode_readable}"
                )
                logging.warning(log_message)

        except Exception as e:
            logging.error(f"Error parsing DNS packet from {src_ip} to {dst_ip}: {e}")
            # Optional: print(packet.show()) to see the full packet structure for debugging

    # else:
    #     logging.debug(f"Non-DNS packet or incomplete DNS packet received: {packet.summary()}")


def main():
    logging.info(f"Starting DNS traffic analysis on interface: {INTERFACE if INTERFACE else 'auto-selected'}")
    logging.info(f"Capturing {COUNT if COUNT > 0 else 'infinite'} packets or for {TIMEOUT if TIMEOUT > 0 else 'no'} seconds...")
    logging.info("Press Ctrl+C to stop the capture.")

    try:
        sniff(
            filter="udp port 53 or tcp port 53", # BPF filter for DNS traffic (UDP or TCP)
            prn=dns_parser,                      # Function to call for each packet
            store=0,                             # Do not store packets in memory (save resources)
            iface=INTERFACE,                     # Specify network interface
            count=COUNT,                         # Number of packets to capture
            timeout=TIMEOUT                      # Timeout for sniffing
        )
    except PermissionError:
        logging.critical("Permission denied. You might need to run this script with root/administrator privileges (e.g., sudo python3 script.py).")
    except ImportError:
        logging.critical("Scapy not found. Please install it using 'pip install scapy'.")
    except Exception as e:
        logging.critical(f"An error occurred during sniffing: {e}")

    logging.info("DNS traffic analysis finished.")

if __name__ == "__main__":
    main()
