# Paperless-NGX

A community-supported supercharged document management system: scan, index and archive all your documents.

## Deployment

Paperless-NGX is deployed with:
- **PostgreSQL 16** - Database backend
- **Redis 7** - Task queue and caching
- **Paperless-NGX** (latest) - Main application

## Access

- **URL**: https://paperless.botocudo.net
- **Username**: admin
- **Password**: admin123
- **Email**: admin@botocudo.net

**⚠️ Important**: Change the default password after first login!

## Features

- **OCR Support**: Automatic text recognition from scanned documents
- **Full-text Search**: Find documents by content, not just filename
- **Tags & Correspondents**: Organize documents your way
- **Document Types**: Categorize by type (invoice, contract, etc.)
- **Automatic Matching**: Rules to auto-tag and categorize incoming documents
- **REST API**: Full API access for automation
- **Mobile Friendly**: Responsive web interface

## Storage

Currently using ephemeral storage (`emptyDir`). For production use, you should configure persistent volumes:

```yaml
volumes:
- name: data
  persistentVolumeClaim:
    claimName: paperless-data
- name: media
  persistentVolumeClaim:
    claimName: paperless-media
```

## Configuration

Key environment variables set:
- `PAPERLESS_URL`: https://paperless.botocudo.net
- `PAPERLESS_TIME_ZONE`: UTC (adjust as needed)
- `PAPERLESS_OCR_LANGUAGE`: eng (English)
- `PAPERLESS_SECRET_KEY`: **Change this in production!**

## Consuming Documents

Documents can be added through:
1. **Web Interface**: Upload directly through the UI
2. **Email**: Configure mail rules to auto-import from email
3. **Consume Folder**: Drop files into `/usr/src/paperless/consume`
4. **API**: Use the REST API for programmatic uploads

## Resources

- Paperless: 512Mi-1Gi RAM, 200m-1000m CPU
- PostgreSQL: 256Mi-512Mi RAM, 100m-500m CPU  
- Redis: 64Mi-128Mi RAM, 50m-100m CPU

## Documentation

- Official Docs: https://docs.paperless-ngx.com
- GitHub: https://github.com/paperless-ngx/paperless-ngx
- Demo: https://demo.paperless-ngx.com (demo/demo)

## Troubleshooting

**Check pod logs**:
```bash
kubectl logs -n paperless -l app=paperless
```

**Check database connection**:
```bash
kubectl exec -n paperless -it deployment/postgresql -- psql -U paperless -d paperless -c "SELECT version();"
```

**Restart application**:
```bash
kubectl rollout restart deployment paperless -n paperless
```

## Security Notes

⚠️ **Important Security Considerations**:

1. **Change default credentials** immediately after deployment
2. **Update SECRET_KEY** to a random string (minimum 50 characters)
3. **Enable HTTPS** (already configured via Traefik)
4. **Consider persistent storage** for important documents
5. **Regular backups** of the database and media directory
6. **Review exposed ports** and access controls

Document scanners handle sensitive information - ensure your deployment is secure!
