# API Documentation

## GET /api/users

Returns a list of users.

### Parameters
None. We believe in simplicity.

### Response
```json
{
  "users": ["probably some users"],
  "error": null,
  "mood": "optimistic"
}
```

## POST /api/users

Creates a user. Maybe.

### Parameters
- `name`: string (required) - The user's name
- `email`: string (required) - A valid email, we pinky promise we'll validate it
- `favorite_color`: string (optional) - For important business reasons

### Response
If successful: HTTP 201
If unsuccessful: HTTP 500 and tears

## DELETE /api/users/:id

Deletes a user. This action cannot be undone. Probably. We haven't tested the backups in a while.
