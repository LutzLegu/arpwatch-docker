FROM opensuse/leap:15.6

ENV container=docker

# Install required packages
RUN zypper --non-interactive up && \
    zypper --non-interactive in arpwatch vim sudo systemd iproute2 mc postfix mailx

# Use sed to replace line
# Postfix Empfang auf Port 25 aus
RUN sed -i 's/^\(smtp.*inet.*\)/#####\1/' /etc/postfix/master.cf
RUN sed -i '1 i root: lutz@legutke.local' /etc/aliases
RUN newaliases

# /etc/mailrc Initialisierung
RUN echo -e "# Config file for mailx\n\
#\n\
set asksub append dot save crt=20\n\
ignore Recieved Message-Id Resent-Message-Id Status Mail-From Return-Path Via\n\
set smtp=smtp://192.168.1.1\n\
set from=root@foo.bar" > /etc/mail.rc

# Startfile erzeugen - Variable einlesen
RUN echo -e "#!/bin/bash\n\
#Startdatei setzt Variable \n\
set -e\n\
sed -i \"s;^set smtp=.*;smtp=smtp://\$SMTP_HOST;\" /etc/mail.rc\n\
sed -i \"s/^set from=.*/from=\$MAIL_FROM/\" /etc/mail.rc\n\
sed -i \"s/^ARPWATCH_INTERFACE=.*/ARPWATCH_INTERFACE=\\\"\"\$ARPWATCH_INTERFACE\"\\\"/\" /etc/sysconfig/arpwatch\n\
sed -i \"s/^ARPWATCH_ARGS=.*/ARPWATCH_ARGS=\\\"-i \"\$ARPWATCH_INTERFACE\" -e \"\$MAIL_TO\"\\\"/\" /etc/sysconfig/arpwatch\n\
sed -i \"s/^POSTFIX_RELAYHOST=.*/POSTFIX_RELAYHOST=\\\"\"\$SMTP_HOST\"\\\"/\" /etc/sysconfig/postfix\n\
postconf -e \"myorigin = \$POSTFIX_MYORIGIN\"\n\
postconf -e \"myhostname = \$POSTFIX_MYHOSTNAME\"\n\
exec \"\$@\"" > /root/bin/start.sh

RUN chown root:root /root/bin/start.sh
RUN chmod 700 /root/bin/start.sh

# Ensure permissions for log directory
RUN mkdir -p /var/log && chown -R root:root /var/log

# Postfix initial einrichten
RUN postconf -e 'mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]104 [::1]/128'
RUN postconf -e 'inet_interfaces = loopback-only'
RUN postconf -e 'relay_transport = relay'
RUN postconf -e 'default_transport = smtp'
# RUN postconf -e 'mydestination =' wird ueberschrieben ?

# Enable the needed services
RUN systemctl enable postfix.service
RUN systemctl enable arpwatch.service

# Configure systemd
STOPSIGNAL SIGRTMIN+3
CMD ["/usr/lib/systemd/systemd"]
ENTRYPOINT ["/root/bin/start.sh"]
