## Development

### Requirements

- Ruby 3.2
- Node.js 20
- libvips
- FFmpeg

Make sure you have installed all those dependencies.

### Install gem dependencies

```shell
bundle install
```

### Install JavaScript dependencies

```shell
npm install
```

### Database Configuration

```shell
rails db:prepare
rails db:seed
```

### Start all services

After you’ve set up everything, now you can running `./bin/dev` to start all service you need to develop.
Then visit <http://localhost:3000> use initial admin user to login (email: admin@admin.com, password: foobar).


## Test

```shell
# Running all test
$ rails test:all 

# Running lint
$ rails lint:all
```

## Integrations

Black Candy support get artist and album image from Discogs API. You can create a API token from Discogs and set Discogs token on Setting page to enable it.