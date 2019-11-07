FROM debian:stable-slim
LABEL maintainer="kevin@meredithkm.info"

ARG BUILD=prod
ARG uwsgi_uid=700
ARG uwsgi_gid=700

ENV BUILD=$BUILD
ENV DOCKER_CONTAINER=1
ENV UWSGI_INI /nsupdate/uwsgi.ini
ENV DJANGO_SETTINGS_MODULE=local_settings
ENV DJANGO_SUPERUSER=django
ENV DJANGO_SUPERPASS=S3cr3t
ENV DJANGO_EMAIL=django@nsupdate.localdomain
ENV SERVICE_CONTACT=hostmaster@nsupdate.localdomain
ENV SECRET_KEY=S3cr3t
ENV BASEDOMAIN=nsupdate.localdomain

RUN mkdir /static
RUN mkdir /upload
RUN mkdir /var/run/uwsgi

# Install python3 and pip
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && apt-get install -y --no-install-recommends \
       git \
       python3 \
       python3-setuptools \
       python3-pip \
       python3-dev \
       python3-wheel \
       python3-django-uwsgi \
       python3-psycopg2 \
       build-essential \
       libpcre3 \
       libpcre3-dev \
    && rm -rf /tmp/* /var/tmp/* \
    && rm -rf /var/lib/apt/lists/*

# Make dirs
RUN mkdir -p /etc/confd/{conf.d,templates}

# Add templates
COPY build/confd/ /etc/confd/

# Add confd
ADD https://github.com/kelseyhightower/confd/releases/download/v0.16.0/confd-0.16.0-linux-amd64 /usr/local/bin/confd
RUN chmod +x /usr/local/bin/confd

# Set up the ENTRYPOINT
COPY build/docker-entrypoint.sh /var/local/
RUN chmod a+x /var/local/docker-entrypoint.sh

# Clone latest version of nsupdate from GitHub
RUN git clone https://github.com/nsupdate-info/nsupdate.info.git nsupdate

#Allow superuser for django to be created via script instead of interactive
ADD build/django/create-superuser.py /nsupdate/nsupdate/management/commands/create-superuser.py

# Install easy-install wrapper scripts
#COPY ./build/bin/pip /bin/pip

WORKDIR /nsupdate

#RUN pip install wheel # Installed via apt
RUN python3 setup.py bdist_wheel
RUN python3 -m pip install psycopg2 uwsgi
RUN python3 -m pip install -r requirements.d/$BUILD.txt
RUN python3 -m pip install -e .

# Add uwsgi ini file
ADD build/uwsgi.ini uwsgi.ini

# Copy the permission script.
COPY build/setup.sh /

# Launch setup.sh
RUN bash /setup.sh "${uwsgi_uid}" "${uwsgi_gid}"

VOLUME /nsupdate
VOLUME /static
VOLUME /upload
VOLUME /var/run/uwsgi

EXPOSE 3031

ENTRYPOINT ["/var/local/docker-entrypoint.sh"]
